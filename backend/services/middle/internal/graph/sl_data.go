package graph

import (
	"fmt"
	"log"
	"os"
	"sort"
	"strings"

	"github.com/gocarina/gocsv"
)

func (graph *SLGraph) initFromDir(dir string) error {
	paths := [5]string{
		dir + "/sl_agency.csv",
		dir + "/sl_routes.csv",
		dir + "/sl_stop_times.csv",
		dir + "/sl_stops.csv",
		dir + "/sl_trips.csv",
	}
	return graph.initFromPaths(paths[0], paths[1], paths[2], paths[3], paths[4])
}

func (graph *SLGraph) init() error {
	dir := os.Getenv("SL_DATA_DIR")
	if dir == "" {
		dir = "/app/backend/services/middle/data"
	}
	return graph.initFromDir(dir)
}

func (graph *SLGraph) initFromPaths(agencyPath, routesPath, stopTimesPath, stopsPath, tripsPath string) error {
	_, _, stopTimes, stops, _, err := loadFromPaths(agencyPath, routesPath, stopTimesPath, stopsPath, tripsPath)
	if err != nil {
		return err
	}
	for _, stop := range stops {
		v := NewVertex(stop.StopID)
		stop.StopNameLower = strings.ToLower(stop.StopName)
		v.SetMetadata(stop)
		graph.AddVertex(v)
	}
	stopTimeMap := make(map[string][]StopTimes)
	for _, stopTime := range stopTimes {
		stopTimeMap[stopTime.TripID] = append(stopTimeMap[stopTime.TripID], *stopTime)
	}
	for tripID, times := range stopTimeMap {
		sort.Slice(times, func(i, j int) bool {
			return times[i].StopSequence < times[j].StopSequence
		})
		stopTimeMap[tripID] = times
	}
	for _, times := range stopTimeMap {
		for i := 0; i < len(times)-1; i++ {
			from := times[i]
			to := times[i+1]
			fromV := graph.GetVertexByID(from.StopID)
			toV := graph.GetVertexByID(to.StopID)
			if fromV == nil || toV == nil {
				continue
			}
			props := EdgeProperties{
				TripID:         from.TripID,
				Departure:      toMinutes(from.DepartureTime),
				Arrival:        toMinutes(to.ArrivalTime),
				TransferType:   COMMUTE_EDGE,
				SourceStopName: fromV.metadata.StopName,
				DestStopName:   toV.metadata.StopName,
			}
			if _, err := graph.AddEdge(fromV, toV, props); err != nil {
				return err
			}
		}
	}
	return graph.addTransferEdges(stops)
}

func (graph *SLGraph) addTransferEdges(stops []*Stop) error {
	for i, a := range stops {
		for j, b := range stops {
			if i >= j {
				continue
			}
			if a.StopName == b.StopName {
				continue
			}
			dist, err := ApproxDistanceMeters(a, b)
			if err != nil {
				log.Printf("distance error: %v", err)
				continue
			}
			if dist < 400 {
				walkMinutes := int(dist / 80.0)
				if walkMinutes == 0 {
					walkMinutes = 1
				}
				props := EdgeProperties{
					Departure:      0,
					Arrival:        walkMinutes,
					TransferType:   WALK_EDGE,
					SourceStopName: a.StopName,
					DestStopName:   b.StopName,
				}
				from := graph.GetVertexByID(a.StopID)
				to := graph.GetVertexByID(b.StopID)
				if _, err := graph.AddEdge(from, to, props); err != nil {
					return err
				}
				if _, err := graph.AddEdge(to, from, props); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func loadFromPaths(agencyPath, routesPath, stopTimesPath, stopsPath, tripsPath string) ([]*Agency, []*Routes, []*StopTimes, []*Stop, []*Trips, error) {
	agencies, err := loadCSV[Agency](agencyPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	routes, err := loadCSV[Routes](routesPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	stopTimes, err := loadCSV[StopTimes](stopTimesPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	stops, err := loadCSV[Stop](stopsPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	trips, err := loadCSV[Trips](tripsPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	return agencies, routes, stopTimes, stops, trips, nil
}

func loadCSV[T any](path string) ([]*T, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var records []*T
	if err := gocsv.Unmarshal(f, &records); err != nil {
		return nil, err
	}
	return records, nil
}

func toMinutes(t string) int {
	var h, m, s int
	fmt.Sscanf(t, "%d:%d:%d", &h, &m, &s)
	return h*60 + m
}
