package controller

import (
	"encoding/json"
	"math"
	"net/http"
	"sort"
	"sync"
	"time"
	"context"

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
	spreadThreshold       = 10    // target max transit time spread in minutes
	baseSearchRadius      = 500.0
	maxSearchRadius       = 4000.0
	maxScoredCandidates   = 20    // cap A* work per request
)

func MiddleEndpoint(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 12*time.Second)
	defer cancel()

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
		t0 := time.Now()
		candidates, err = searchGrid(*centroid, locationType, radius)
		if err != nil {
			plog.Error(err)
			http.Error(w, "couldn't find nearby places", http.StatusInternalServerError)
			return
		}
		plog.Infof("overpass took %dms, %d candidates", time.Since(t0).Milliseconds(), len(candidates))

		t1 := time.Now()
		var partial bool
		ranked, partial = scoreAndRank(ctx, candidates, inputStopSets, g, *centroid, false)
		plog.Infof("scoring %d candidates took %dms (partial=%v)", len(candidates), time.Since(t1).Milliseconds(), partial)

		if partial {
			break
		}

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

	if len(ranked) > 0 && ranked[0].spread > spreadThreshold && ranked[0].spread < math.MaxInt {
		select {
		case <-ctx.Done():
			plog.Warning("skipping SL API validation pass, context deadline exceeded")
		default:
			plog.Infof("spread %d min after radius expansion, retrying with SL API validation", ranked[0].spread)
			validated, _ := scoreAndRank(ctx, candidates, inputStopSets, g, *centroid, true)
			if len(validated) > 0 && validated[0].spread < ranked[0].spread {
				ranked = validated
			}
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

func scoreAndRank(ctx context.Context, candidates []places.Place, inputStopSets [][]*graph.Vertex, g *graph.SLGraph, centroid location.Point, validate bool) ([]scoredPlace, bool) {
	if len(candidates) > maxScoredCandidates {
		sort.Slice(candidates, func(i, j int) bool {
			return approxDistSq(centroid.Latitude, centroid.Longitude, candidates[i].Location.Latitude, candidates[i].Location.Longitude) <
    			approxDistSq(centroid.Latitude, centroid.Longitude, candidates[j].Location.Latitude, candidates[j].Location.Longitude)
		})
		candidates = candidates[:maxScoredCandidates]
	}

	type distMap = map[uint32]int
	var srcMaps []distMap
	allComplete := true

	if !validate {
		srcMaps = make([]distMap, len(inputStopSets))
		var wgDijk sync.WaitGroup
		var mu sync.Mutex
		for i, srcSet := range inputStopSets {
			wgDijk.Add(1)
			go func(i int, srcSet []*graph.Vertex) {
				defer wgDijk.Done()
				merged := make(distMap)
				for _, src := range srcSet {
					dm, complete := g.AllTravelTimesFrom(ctx, src, startTime)
					if !complete {
						mu.Lock()
						allComplete = false
						mu.Unlock()
					}
					for stopIdx, t := range dm {
						if existing, ok := merged[stopIdx]; !ok || t < existing {
							merged[stopIdx] = t
						}
					}
				}
				srcMaps[i] = merged
			}(i, srcSet)
		}
		wgDijk.Wait()
	}

	lookupTravel := func(srcIdx int, dst *graph.Vertex) int {
		if srcMaps != nil {
			if t, ok := srcMaps[srcIdx][dst.Idx()]; ok {
				return t
			}
			return -1
		}
		best := math.MaxInt
		for _, src := range inputStopSets[srcIdx] {
			if t := g.TravelMinutesValidated(src, dst, startTime); t >= 0 && t < best {
				best = t
			}
		}
		if best == math.MaxInt {
			return -1
		}
		return best
	}

	scored := make([]scoredPlace, len(candidates))
	var wg sync.WaitGroup
	for i, place := range candidates {
		wg.Add(1)
		go func(i int, place places.Place) {
			defer wg.Done()
			placeStops := g.FindNClosestStops(place.Location.Latitude, place.Location.Longitude, nearestStopCandidates)
			if len(placeStops) == 0 {
				scored[i] = scoredPlace{place, math.MaxInt, math.MaxInt}
				return
			}

			times := make([]int, 0, len(inputStopSets))
			valid := true
			for srcIdx := range inputStopSets {
				best := math.MaxInt
				for _, dst := range placeStops {
					if t := lookupTravel(srcIdx, dst); t >= 0 && t < best {
						best = t
					}
				}
				if best == math.MaxInt {
					valid = false
					break
				}
				times = append(times, best)
			}

			if !valid {
				scored[i] = scoredPlace{place, math.MaxInt, math.MaxInt}
				return
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
			scored[i] = scoredPlace{place, maxT - minT, sum / len(times)}
		}(i, place)
	}
	wg.Wait()

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
		distI := approxDistSq(centroid.Latitude, centroid.Longitude, si.place.Location.Latitude, si.place.Location.Longitude)
		distJ := approxDistSq(centroid.Latitude, centroid.Longitude, sj.place.Location.Latitude, sj.place.Location.Longitude)
		return distI < distJ
	})
	return scored, allComplete
}

type scoredPlace struct {
	place  places.Place
	spread int
	avg    int
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
