package graph

import (
	"container/heap"
	"math"
	"slices"
	"sort"
	"strings"

	plog "github.com/durelius/go-prodlog"
	pq "github.com/durelius/pvt-app/backend/services/middle/internal/priority_queue"
)

const maxTravelMinutes = 60

// routeInfo tracks the edge and parent state for path reconstruction.
type routeInfo struct {
	edge    *Edge
	prevKey pq.StateKey
}

// FindRoute finds the fastest route between two stops using A* on real SL timetable data.
// startTime is minutes since midnight (e.g. 9*60 for 09:00).
// Returns the edges forming the path, or nil if no route found.
func (graph *SLGraph) FindRoute(start *Vertex, destination *Vertex, startTime int) []*Edge {
	open := make(pq.PriorityQueue, 0, 1024)
	heap.Init(&open)

	startKey := pq.MakeKey(start.idx, 0, false)
	heap.Push(&open, pq.Item{Key: startKey, G: startTime, F: startTime})

	closed := make(map[pq.StateKey]bool)
	bestG := make(map[pq.StateKey]int)
	bestG[startKey] = startTime
	cameFrom := make(map[pq.StateKey]routeInfo)

	for len(open) > 0 {
		current := heap.Pop(&open).(pq.Item)
		curKey := current.Key
		currentStop := graph.vertexByIdx[curKey.VertexIdx()]

		if currentStop == destination {
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

		walked := curKey.Walked()
		tripID := curKey.Trip

		for _, edge := range currentStop.edges {
			if edge.Metadata.TransferType == WALK_EDGE && walked {
				continue
			}
			newG := edge.calculateG(current.G, tripID)
			if newG == -1 || newG > startTime+maxTravelMinutes {
				continue
			}
			var neighborKey pq.StateKey
			if edge.Metadata.TransferType == WALK_EDGE {
				neighborKey = pq.MakeKey(edge.dest.idx, 0, true)
			} else {
				neighborKey = pq.MakeKey(edge.dest.idx, edge.Metadata.TripID, false)
			}
			if best, exists := bestG[neighborKey]; !exists || newG < best {
				bestG[neighborKey] = newG
				h := calculateH(edge.dest.metadata, destination.metadata)
				heap.Push(&open, pq.Item{Key: neighborKey, G: newG, F: newG + h})
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

// TravelMinutesValidated is like TravelMinutes but uses the SL Journey Planner API
// as a fallback for pairs where A* found no local path. Cached local results are
// returned as-is without hitting the API.
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

	var localMinutes int
	if validate {
		if cached, ok := graph.travelCache.Load(cacheKey); ok {
			if cached.(int) == noPath {
				localMinutes = noPath
			} else {
				return cached.(int)
			}
		} else {
			path := graph.FindRoute(start, destination, startTime)
			if len(path) == 0 {
				localMinutes = noPath
			} else {
				localMinutes = replayPath(path, startTime)
			}
		}
	} else {
		path := graph.FindRoute(start, destination, startTime)
		if len(path) == 0 {
			graph.travelCache.Store(cacheKey, noPath)
			return -1
		}
		localMinutes = replayPath(path, startTime)
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
	minutes, err := slPointSearch(sm.LatF, sm.LonF, dm.LatF, dm.LonF)
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

// AllTravelTimesFrom runs a full Dijkstra from start, returning the minimum travel
// minutes to every reachable stop within maxTravelMinutes. Uses value-typed priority
// queue items (no per-item heap allocation) and struct state keys (no string allocs).
// Results are cached in srcCache keyed by vertex index.
func (graph *SLGraph) AllTravelTimesFrom(start *Vertex, startTime int) map[uint32]int {
	if cached, ok := graph.srcCache.Load(start.idx); ok {
		return cached.(map[uint32]int)
	}

	open := make(pq.PriorityQueue, 0, 4096)
	heap.Init(&open)

	startKey := pq.MakeKey(start.idx, 0, false)
	heap.Push(&open, pq.Item{Key: startKey, G: startTime, F: startTime})

	closed := make(map[pq.StateKey]bool, 32768)
	bestG := make(map[pq.StateKey]int, 32768)
	bestG[startKey] = startTime
	bestByStop := make(map[uint32]int, 4096)

	for len(open) > 0 {
		current := heap.Pop(&open).(pq.Item)
		curKey := current.Key

		if closed[curKey] {
			continue
		}
		closed[curKey] = true

		stopIdx := curKey.VertexIdx()
		travelTime := current.G - startTime
		if existing, ok := bestByStop[stopIdx]; !ok || travelTime < existing {
			bestByStop[stopIdx] = travelTime
		}

		currentStop := graph.vertexByIdx[stopIdx]
		walked := curKey.Walked()
		tripID := curKey.Trip

		for _, edge := range currentStop.edges {
			if edge.Metadata.TransferType == WALK_EDGE && walked {
				continue
			}
			newG := edge.calculateG(current.G, tripID)
			if newG == -1 || newG > startTime+maxTravelMinutes {
				continue
			}
			var neighborKey pq.StateKey
			if edge.Metadata.TransferType == WALK_EDGE {
				neighborKey = pq.MakeKey(edge.dest.idx, 0, true)
			} else {
				neighborKey = pq.MakeKey(edge.dest.idx, edge.Metadata.TripID, false)
			}
			if best, exists := bestG[neighborKey]; !exists || newG < best {
				bestG[neighborKey] = newG
				heap.Push(&open, pq.Item{Key: neighborKey, G: newG, F: newG})
			}
		}
	}

	graph.srcCache.Store(start.idx, bestByStop)
	return bestByStop
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

// replayPath simulates the path through calculateG to get accurate end-to-end
// travel time. Using Metadata.Arrival directly is wrong for walk edges, where
// Arrival stores duration rather than absolute clock time.
func replayPath(path []*Edge, startTime int) int {
	currentTime := startTime
	var currentTripID uint32
	for _, e := range path {
		g := e.calculateG(currentTime, currentTripID)
		if g < 0 {
			return g
		}
		currentTime = g
		if e.Metadata.TransferType != WALK_EDGE {
			currentTripID = e.Metadata.TripID
		} else {
			currentTripID = 0
		}
	}
	return currentTime - startTime
}
