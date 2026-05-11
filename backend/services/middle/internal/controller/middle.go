package controller

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"sort"

	"github.com/durelius/pvt-app/backend/services/middle/internal/graph"
	"github.com/durelius/pvt-app/backend/services/middle/internal/middle"
	"github.com/durelius/pvt-app/backend/services/middle/internal/places"
	"github.com/durelius/pvt-app/backend/shared/models/location"
)

const (
	startTime  = 9 * 60 // 09:00
	maxResults = 5
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

	candidates, err := places.Nearby(*centroid, locationType)
	if err != nil {
		log.Println(err)
		http.Error(w, "couldn't find nearby places", http.StatusInternalServerError)
		return
	}

	ranked := rankByTransitFairness(candidates, points)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ranked)
}

const (
	nearestStopCandidates = 3
	spreadFallbackMin     = 15 // trigger SL API validation pass when best spread exceeds this
)

type scoredPlace struct {
	place  places.Place
	spread int
	avg    int
}

// rankByTransitFairness scores each place by spread (max−min travel time across
// inputs), with average as tiebreaker. If the best spread exceeds spreadFallbackMin,
// a second pass using SL API validation is attempted. Falls back to centroid order
// if neither pass produces a spread within the threshold.
func rankByTransitFairness(candidates []places.Place, inputs []location.Point) []places.Place {
	g := graph.Instance()

	inputStopSets := make([][]*graph.Vertex, len(inputs))
	for i, p := range inputs {
		inputStopSets[i] = g.FindNClosestStops(p.Latitude, p.Longitude, nearestStopCandidates)
		if len(inputStopSets[i]) == 0 {
			log.Println("no stop found for input, falling back to centroid order")
			return cap5(candidates)
		}
	}

	ranked := scoreAndRank(candidates, inputStopSets, g, false)

	bestSpread := math.MaxInt
	if len(ranked) > 0 {
		bestSpread = ranked[0].spread
	}

	if bestSpread > spreadFallbackMin && bestSpread < math.MaxInt {
		// Some routes scored but spread is high — try SL API validation.
		log.Printf("local spread %d min exceeds threshold, retrying with SL API validation", bestSpread)
		ranked = scoreAndRank(candidates, inputStopSets, g, true)
		bestSpread = math.MaxInt
		if len(ranked) > 0 {
			bestSpread = ranked[0].spread
		}
	}

	if bestSpread > spreadFallbackMin {
		log.Printf("spread %d min, falling back to centroid order", bestSpread)
		return cap5(candidates)
	}

	result := make([]places.Place, 0, maxResults)
	for i, s := range ranked {
		if i >= maxResults {
			break
		}
		log.Printf("ranked #%d: %s (spread %d min, avg %d min)", i+1, s.place.DisplayName.Text, s.spread, s.avg)
		result = append(result, s.place)
	}
	return result
}

func scoreAndRank(candidates []places.Place, inputStopSets [][]*graph.Vertex, g *graph.SLGraph, validate bool) []scoredPlace {
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
		if scored[i].spread != scored[j].spread {
			return scored[i].spread < scored[j].spread
		}
		return scored[i].avg < scored[j].avg
	})
	return scored
}

func cap5(ps []places.Place) []places.Place {
	if len(ps) <= maxResults {
		return ps
	}
	return ps[:maxResults]
}
