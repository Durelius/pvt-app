package graph

import (
	"math"
	"sort"
	"strconv"
)

func calculateH(from *Stop, destination *Stop) int {
	dist, err := ApproxDistanceMeters(from, destination)
	if err != nil {
		return 0
	}
	return int(dist / 1166.0)
}

func (e *Edge) calculateG(currentTime int, currentTripID string) int {
	if e.Metadata.TransferType == WALK_EDGE {
		return currentTime + e.Metadata.Arrival + 5
	}
	if e.Metadata.Departure < currentTime {
		return -1
	}
	waitTime := e.Metadata.Departure - currentTime
	travelTime := e.Metadata.Arrival - e.Metadata.Departure
	penalty := 0
	if currentTripID != "" && e.Metadata.TripID != "" && currentTripID != e.Metadata.TripID {
		penalty = 5
	}
	return currentTime + waitTime + travelTime + penalty
}

func ApproxDistanceMeters(from *Stop, to *Stop) (float64, error) {
	fromLat, err := strconv.ParseFloat(from.StopLatitude, 64)
	if err != nil {
		return 0, err
	}
	fromLong, err := strconv.ParseFloat(from.StopLongitude, 64)
	if err != nil {
		return 0, err
	}
	toLat, err := strconv.ParseFloat(to.StopLatitude, 64)
	if err != nil {
		return 0, err
	}
	toLong, err := strconv.ParseFloat(to.StopLongitude, 64)
	if err != nil {
		return 0, err
	}
	return haversineMeters(fromLat, fromLong, toLat, toLong), nil
}

func haversineMeters(lat1, lon1, lat2, lon2 float64) float64 {
	r := 6378100.0
	lat1r := lat1 * math.Pi / 180
	lon1r := lon1 * math.Pi / 180
	lat2r := lat2 * math.Pi / 180
	lon2r := lon2 * math.Pi / 180
	h := math.Pow(math.Sin((lat2r-lat1r)/2), 2) +
		math.Cos(lat1r)*math.Cos(lat2r)*math.Pow(math.Sin((lon2r-lon1r)/2), 2)
	return 2 * r * math.Asin(math.Sqrt(h))
}

// FindStopsWithinRadius returns all stops within radiusMeters of the given coordinates.
func (graph *SLGraph) FindStopsWithinRadius(lat, lon, radiusMeters float64) []*Vertex {
	probe := &Stop{
		StopLatitude:  strconv.FormatFloat(lat, 'f', 6, 64),
		StopLongitude: strconv.FormatFloat(lon, 'f', 6, 64),
	}
	var result []*Vertex
	for _, v := range graph.vertices {
		if v.metadata == nil {
			continue
		}
		dist, err := ApproxDistanceMeters(probe, v.metadata)
		if err != nil {
			continue
		}
		if dist <= radiusMeters {
			result = append(result, v)
		}
	}
	return result
}

// FindNearestStop returns the closest SL stop vertex to the given coordinates.
func (graph *SLGraph) FindNearestStop(lat, lon float64) *Vertex {
	stops := graph.FindNClosestStops(lat, lon, 1)
	if len(stops) == 0 {
		return nil
	}
	return stops[0]
}

// FindNClosestStops returns the n closest SL stops to the given coordinates, sorted by distance.
func (graph *SLGraph) FindNClosestStops(lat, lon float64, n int) []*Vertex {
	type entry struct {
		v    *Vertex
		dist float64
	}
	probe := &Stop{
		StopLatitude:  strconv.FormatFloat(lat, 'f', 6, 64),
		StopLongitude: strconv.FormatFloat(lon, 'f', 6, 64),
	}
	entries := make([]entry, 0, len(graph.vertices))
	for _, v := range graph.vertices {
		if v.metadata == nil {
			continue
		}
		dist, err := ApproxDistanceMeters(probe, v.metadata)
		if err != nil {
			continue
		}
		entries = append(entries, entry{v, dist})
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].dist < entries[j].dist })
	result := make([]*Vertex, 0, n)
	for i := 0; i < n && i < len(entries); i++ {
		result = append(result, entries[i].v)
	}
	return result
}
