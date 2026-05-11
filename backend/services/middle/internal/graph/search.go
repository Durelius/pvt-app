package graph

import (
	"container/heap"
	"math"
	"slices"
	"sort"
	"strconv"
	"strings"

	plog "github.com/durelius/go-prodlog"
	pq "github.com/durelius/pvt-app/backend/services/middle/internal/priority_queue"
)

// routeState is a (stopID, tripID) pair used as the A* state key.
// Transit routing requires trip awareness in the state: arriving at a stop
// "on trip X" is distinct from "on trip Y" because continuing on the same
// trip has no transfer penalty while switching trips does.
type routeState struct {
	stopID string
	tripID string // empty for walk arrivals and the initial state
}

func (s routeState) key() string { return s.stopID + "\x00" + s.tripID }

type routeInfo struct {
	edge     *Edge
	prevKey  string
}

// FindRoute finds the fastest route between two stops using A* on real SL timetable data.
// startTime is minutes since midnight (e.g. 8*60+30 for 08:30).
// Returns the edges forming the path, or nil if no route found.
func (graph *SLGraph) FindRoute(start *Vertex, destination *Vertex, startTime int) []*Edge {
	open := make(pq.PriorityQueue, 0)
	heap.Init(&open)

	startState := routeState{stopID: start.metadata.StopID, tripID: ""}
	startKey := startState.key()
	heap.Push(&open, pq.NewItem(startKey, startTime, startTime))

	closed := make(map[string]bool)
	bestG := make(map[string]int)
	bestG[startKey] = startTime
	cameFrom := make(map[string]routeInfo)

	for len(open) > 0 {
		current := heap.Pop(&open).(*pq.Item)
		curKey := current.Value()
		stopID, tripID, _ := strings.Cut(curKey, "\x00")
		currentStop := graph.GetVertexByID(stopID)

		if stopID == destination.label {
			var path []*Edge
			key := curKey
			for key != startKey {
				info, ok := cameFrom[key]
				if !ok {
					plog.Warning("route reconstruction error")
					return nil
				}
				path = append(path, info.edge)
				key = info.prevKey
			}
			slices.Reverse(path)
			return path
		}

		if closed[curKey] {
			continue
		}
		closed[curKey] = true

		for _, edge := range currentStop.edges {
			newG := edge.calculateG(current.G(), tripID)
			if newG == -1 {
				continue
			}
			var neighborKey string
			if edge.Metadata.TransferType == WALK_EDGE {
				neighborKey = routeState{stopID: edge.dest.label, tripID: ""}.key()
			} else {
				neighborKey = routeState{stopID: edge.dest.label, tripID: edge.Metadata.TripID}.key()
			}
			if best, exists := bestG[neighborKey]; !exists || newG < best {
				bestG[neighborKey] = newG
				neighborStop := graph.GetVertexByID(edge.dest.label)
				h := calculateH(neighborStop.metadata, destination.metadata)
				heap.Push(&open, pq.NewItem(neighborKey, newG, newG+h))
				cameFrom[neighborKey] = routeInfo{edge: edge, prevKey: curKey}
			}
		}
	}
	return nil
}

// TravelMinutes returns the local-graph travel time in minutes (A* only, no SL API).
// Returns -1 if no route found. Results are cached.
func (graph *SLGraph) TravelMinutes(start *Vertex, destination *Vertex, startTime int) int {
	return graph.travelMinutes(start, destination, startTime, false)
}

// TravelMinutesValidated is like TravelMinutes but cross-checks suspicious results
// against the SL Journey Planner API. Use this when the local spread is high and
// you want a more accurate second-pass estimate. Bypasses the cache so results
// are always fresh; writes the validated result back to cache.
func (graph *SLGraph) TravelMinutesValidated(start *Vertex, destination *Vertex, startTime int) int {
	if graph.skipAPIValidation {
		return graph.TravelMinutes(start, destination, startTime)
	}
	return graph.travelMinutes(start, destination, startTime, true)
}

func (graph *SLGraph) travelMinutes(start *Vertex, destination *Vertex, startTime int, validate bool) int {
	if start.label == destination.label {
		return 0
	}

	cacheKey := start.label + ":" + destination.label
	if !validate {
		if cached, ok := graph.travelCache.Load(cacheKey); ok {
			return cached.(int)
		}
	}

	const noPath = -2 // sentinel cached when A* finds no route

	// On validate pass, if we already know there's no local path, skip A* and go
	// straight to the SL API. Otherwise run A*.
	var localMinutes int
	if validate {
		if cached, ok := graph.travelCache.Load(cacheKey); ok && cached.(int) == noPath {
			localMinutes = noPath
		} else {
			path := graph.FindRoute(start, destination, startTime)
			if len(path) == 0 {
				localMinutes = noPath
			} else {
				localMinutes = path[len(path)-1].Metadata.Arrival - startTime
			}
		}
	} else {
		path := graph.FindRoute(start, destination, startTime)
		if len(path) == 0 {
			graph.travelCache.Store(cacheKey, noPath)
			return -1
		}
		localMinutes = path[len(path)-1].Metadata.Arrival - startTime
		graph.travelCache.Store(cacheKey, localMinutes)
		return localMinutes
	}

	// validate pass below
	var result int
	if localMinutes == noPath {
		if graph.skipAPIValidation {
			return -1
		}
		result = graph.fetchSLAPIMinutes(start, destination)
		if result < 0 {
			return -1
		}
		plog.Infof("no local path for %s→%s, SL API returned %d min", start.Metadata().StopName, destination.Metadata().StopName, result)
	} else {
		result = graph.validateWithSLAPI(start, destination, localMinutes)
	}

	graph.travelCache.Store(cacheKey, result)
	return result
}

func (graph *SLGraph) fetchSLAPIMinutes(start, destination *Vertex) int {
	sm := start.Metadata()
	dm := destination.Metadata()
	fromLat, err1 := strconv.ParseFloat(sm.StopLatitude, 64)
	fromLon, err2 := strconv.ParseFloat(sm.StopLongitude, 64)
	toLat, err3 := strconv.ParseFloat(dm.StopLatitude, 64)
	toLon, err4 := strconv.ParseFloat(dm.StopLongitude, 64)
	if err1 != nil || err2 != nil || err3 != nil || err4 != nil {
		return -1
	}
	minutes, err := slPointSearch(fromLat, fromLon, toLat, toLon)
	if err != nil {
		plog.Warningf("SL API fallback failed (%s→%s): %v", sm.StopName, dm.StopName, err)
		return -1
	}
	return minutes
}

func (graph *SLGraph) validateWithSLAPI(start, destination *Vertex, localMinutes int) int {
	apiMinutes := graph.fetchSLAPIMinutes(start, destination)
	if apiMinutes < 0 {
		plog.Warningf("SL API validation failed (%s→%s), keeping local result %d min", start.Metadata().StopName, destination.Metadata().StopName, localMinutes)
		return localMinutes
	}

	diff := math.Abs(float64(apiMinutes-localMinutes)) / float64(localMinutes)
	if diff > 0.2 {
		plog.Infof("SL API result (%d min) differs from local (%d min) by %.0f%% for %s→%s, using API result",
			apiMinutes, localMinutes, diff*100, start.Metadata().StopName, destination.Metadata().StopName)
		return apiMinutes
	}
	return localMinutes
}

func (graph *SLGraph) FindStopsByName(name string) []*Vertex {
	name = strings.ToLower(name)
	var out []*Vertex
	for _, v := range graph.GetAllVertices() {
		if strings.Contains(v.metadata.StopNameLower, name) {
			out = append(out, v)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].label < out[j].label })
	return out
}
