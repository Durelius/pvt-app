package graph

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	plog "github.com/durelius/go-prodlog"
	"github.com/gocarina/gocsv"
)

func (graph *SLGraph) initFromDir(dir string) error {
	return graph.initFromPaths(
		dir+"/sl_agency.csv",
		dir+"/sl_routes.csv",
		dir,
		dir+"/sl_stops.csv",
		dir+"/sl_trips.csv",
	)
}

func (graph *SLGraph) init() error {
	dir := os.Getenv("SL_DATA_DIR")
	if dir == "" {
		dir = "/app/backend/services/middle/data"
	}
	return graph.initFromDir(dir)
}

// stopTimesArg is either a directory (loads sl_stop_times_part*.csv from it)
// or a direct file path (used in tests).
func (graph *SLGraph) initFromPaths(agencyPath, routesPath, stopTimesArg, stopsPath, tripsPath string) error {
	_, _, stopTimes, stops, _, err := loadFromPaths(agencyPath, routesPath, stopTimesArg, stopsPath, tripsPath)
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
				plog.Warningf("distance error: %v", err)
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

func loadFromPaths(agencyPath, routesPath, stopTimesArg, stopsPath, tripsPath string) ([]*Agency, []*Routes, []*StopTimes, []*Stop, []*Trips, error) {
	agencies, err := loadCSV[Agency](agencyPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	routes, err := loadCSV[Routes](routesPath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	stopTimes, err := loadStopTimes(stopTimesArg)
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

// loadStopTimes accepts either a directory (globs sl_stop_times_part*.csv)
// or a direct file path.
func loadStopTimes(arg string) ([]*StopTimes, error) {
	info, err := os.Stat(arg)
	if err != nil {
		return nil, err
	}
	var paths []string
	if info.IsDir() {
		paths, err = filepath.Glob(filepath.Join(arg, "sl_stop_times_part*.csv"))
		if err != nil {
			return nil, err
		}
		sort.Strings(paths)
	} else {
		paths = []string{arg}
	}
	var all []*StopTimes
	for _, p := range paths {
		chunk, err := loadCSV[StopTimes](p)
		if err != nil {
			return nil, fmt.Errorf("loading %s: %w", p, err)
		}
		all = append(all, chunk...)
	}
	return all, nil
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
