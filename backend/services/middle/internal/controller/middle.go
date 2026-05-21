package controller

import (
	"encoding/json"
	"math"
	"net/http"
	"sort"

	plog "github.com/durelius/go-prodlog"
	"github.com/durelius/pvt-app/backend/services/middle/internal/graph"
	"github.com/durelius/pvt-app/backend/services/middle/internal/middle"
	"github.com/durelius/pvt-app/backend/services/middle/internal/places"
	"github.com/durelius/pvt-app/backend/shared/models/location"
)

const (
	startTime             = 9 * 60
	maxResults            = 5
	nearestStopCandidates = 3
	spreadThreshold       = 10   // target max transit time spread in minutes
	baseSearchRadius      = 500.0
	maxSearchRadius       = 4000.0
)

func MiddleEndpoint(w http.ResponseWriter, r *http.Request) {
	rawAddresses := r.URL.Query().Get("addresses")
	rawPoints := r.URL.Query().Get("points")
	if rawAddresses == "" && rawPoints == "" {
		http.Error(w, "provide addresses or points", http.StatusBadRequest)
		return
	}

	var points []location.Point
	if rawAddresses != "" {
		var addresses []location.Address
		if err := json.Unmarshal([]byte(rawAddresses), &addresses); err != nil {
			http.Error(w, "invalid addresses format", http.StatusBadRequest)
			return
		}
		for _, a := range addresses {
			p, err := a.Point()
			if err != nil {
				http.Error(w, "could not geocode address", http.StatusBadRequest)
				return
			}
			points = append(points, *p)
		}
	} else {
		if err := json.Unmarshal([]byte(rawPoints), &points); err != nil {
			http.Error(w, "invalid points format", http.StatusBadRequest)
			return
		}
	}

	locationType := r.URL.Query().Get("location_type")
	if locationType == "" {
		http.Error(w, "missing location_type", http.StatusBadRequest)
		return
	}

	centroid, err := middle.Average(points)
	if err != nil {
		http.Error(w, "couldn't compute centroid", http.StatusBadRequest)
		return
	}

	g := graph.Instance()
	inputStopSets := make([][]*graph.Vertex, len(points))
	for i, p := range points {
		inputStopSets[i] = g.FindNClosestStops(p.Latitude, p.Longitude, nearestStopCandidates)
		if len(inputStopSets[i]) == 0 {
			plog.Warning("no stop found for input, falling back to centroid order")
			candidates, err := places.NearbyOverPass(*centroid, locationType, baseSearchRadius)
			if err != nil {
				plog.Error(err)
				http.Error(w, "couldn't find nearby places", http.StatusInternalServerError)
				return
			}
			capped := cap5(candidates)
			for i := range capped {
				capped[i].Rating = places.ComputeHeuristicRating(capped[i], 0, 0)
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(capped)
			return
		}
	}

	var candidates []places.Place
	var ranked []scoredPlace
	radius := baseSearchRadius

	for {
		candidates, err = searchGrid(*centroid, locationType, radius)
		if err != nil {
			plog.Error(err)
			http.Error(w, "couldn't find nearby places", http.StatusInternalServerError)
			return
		}

		ranked = scoreAndRank(candidates, inputStopSets, g, *centroid, false)

		bestSpread := math.MaxInt
		if len(ranked) > 0 {
			bestSpread = ranked[0].spread
		}

		if bestSpread <= spreadThreshold || radius >= maxSearchRadius {
			break
		}

		radius = math.Min(radius*2, maxSearchRadius)
		plog.Infof("spread %d min exceeds threshold, expanding grid radius to %.0f m", bestSpread, radius)
	}

	// Final SL API validation pass if spread is still above threshold
	if len(ranked) > 0 && ranked[0].spread > spreadThreshold && ranked[0].spread < math.MaxInt {
		plog.Infof("spread %d min after radius expansion, retrying with SL API validation", ranked[0].spread)
		validated := scoreAndRank(candidates, inputStopSets, g, *centroid, true)
		if len(validated) > 0 && validated[0].spread < ranked[0].spread {
			ranked = validated
		}
	}

	result := make([]places.Place, 0, maxResults)
	for i, s := range ranked {
		if i >= maxResults || s.spread == math.MaxInt {
			break
		}
		p := s.place
		p.Rating = places.ComputeHeuristicRating(p, s.spread, s.avg)
		plog.Infof("ranked #%d: %s (transit %d min, rating %.1f)", i+1, p.DisplayName.Text, s.avg+s.spread, p.Rating)
		result = append(result, p)
	}

	if len(result) == 0 {
		plog.Warning("no routable places found, falling back to centroid order")
		result = cap5(candidates)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

type scoredPlace struct {
	place  places.Place
	spread int
	avg    int
}

func scoreAndRank(candidates []places.Place, inputStopSets [][]*graph.Vertex, g *graph.SLGraph, centroid location.Point, validate bool) []scoredPlace {
	travel := g.TravelMinutes
	if validate {
		travel = g.TravelMinutesValidated
	}

	scored := make([]scoredPlace, 0, len(candidates))
	for _, place := range candidates {
		placeStops := g.FindNClosestStops(place.Location.Latitude, place.Location.Longitude, nearestStopCandidates)
		if len(placeStops) == 0 {
			scored = append(scored, scoredPlace{place, math.MaxInt, math.MaxInt})
			continue
		}

		times := make([]int, 0, len(inputStopSets))
		valid := true
		for _, srcSet := range inputStopSets {
			best := math.MaxInt
			for _, src := range srcSet {
				for _, dst := range placeStops {
					if t := travel(src, dst, startTime); t >= 0 && t < best {
						best = t
					}
				}
			}
			if best == math.MaxInt {
				valid = false
				break
			}
			times = append(times, best)
		}

		if !valid {
			scored = append(scored, scoredPlace{place, math.MaxInt, math.MaxInt})
			continue
		}

		minT, maxT, sum := times[0], times[0], 0
		for _, t := range times {
			if t < minT {
				minT = t
			}
			if t > maxT {
				maxT = t
			}
			sum += t
		}
		scored = append(scored, scoredPlace{place, maxT - minT, sum / len(times)})
	}

	sort.Slice(scored, func(i, j int) bool {
		si, sj := scored[i], scored[j]
		if si.spread == math.MaxInt {
			return false
		}
		if sj.spread == math.MaxInt {
			return true
		}
		scoreI, scoreJ := si.avg+si.spread, sj.avg+sj.spread
		if scoreI != scoreJ {
			return scoreI < scoreJ
		}
		// Tiebreak: prefer the place closest to the centroid.
		distI := approxDistSq(centroid.Latitude, centroid.Longitude, si.place.Location.Latitude, si.place.Location.Longitude)
		distJ := approxDistSq(centroid.Latitude, centroid.Longitude, sj.place.Location.Latitude, sj.place.Location.Longitude)
		return distI < distJ
	})
	return scored
}

// searchGrid queries Places API from 5 points (centroid + N/S/E/W offset by
// radius) and returns a deduplicated union of all results. This surfaces
// candidates that are off-center but genuinely better transit-wise.
func searchGrid(center location.Point, locationType string, radius float64) ([]places.Place, error) {
	dLat := radius / 111320.0
	dLon := radius / (111320.0 * math.Cos(center.Latitude*math.Pi/180))

	searchPoints := []location.Point{
		center,
		{Latitude: center.Latitude + dLat, Longitude: center.Longitude},
		{Latitude: center.Latitude - dLat, Longitude: center.Longitude},
		{Latitude: center.Latitude, Longitude: center.Longitude + dLon},
		{Latitude: center.Latitude, Longitude: center.Longitude - dLon},
	}

	results, err := places.NearbyOverPassMulti(searchPoints, locationType, radius)
	if err != nil {
		return nil, err
	}
	seen := make(map[string]bool)
	var merged []places.Place
	for _, place := range results {
		if !seen[place.ID] {
			seen[place.ID] = true
			merged = append(merged, place)
		}
	}
	plog.Infof("grid search: %d unique candidates from 5 points at radius %.0f m", len(merged), radius)
	return merged, nil
}

func cap5(ps []places.Place) []places.Place {
	if len(ps) <= maxResults {
		return ps
	}
	return ps[:maxResults]
}

// approxDistSq returns squared lat/lon distance (no Haversine needed for comparison only).
func approxDistSq(lat1, lon1, lat2, lon2 float64) float64 {
	dLat := lat1 - lat2
	dLon := lon1 - lon2
	return dLat*dLat + dLon*dLon
}
