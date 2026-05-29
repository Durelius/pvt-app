package graph

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"

	plog "github.com/durelius/go-prodlog"
	"github.com/gocarina/gocsv"
)

// compactStopTime stores only what edge-building needs, with times pre-parsed to
// int16 minutes and TripID omitted (it lives as the map key instead).
// Compared to StopTimes this cuts per-row map memory from ~99 bytes to ~41 bytes.
type compactStopTime struct {
	StopID       string
	StopSequence int16
	Departure    int16
	Arrival      int16
}

func (graph *SLGraph) initFromDir(dir string) error {
	return graph.initFromPaths(dir, dir+"/sl_stops.csv")
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
func logMem(label string) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	plog.Infof("MEM [%s]: HeapAlloc=%dMB Sys=%dMB HeapInuse=%dMB", label, m.HeapAlloc/1<<20, m.Sys/1<<20, m.HeapInuse/1<<20)
}

func (graph *SLGraph) initFromPaths(stopTimesArg, stopsPath string) error {
	stops, err := loadCSV[Stop](stopsPath)
	if err != nil {
		return err
	}
	for _, stop := range stops {
		if stop.LocationType != "0" {
			continue // skip parent stations, entrances, and other non-boarding nodes
		}
		v := NewVertex(stop.StopID)
		stop.StopNameLower = strings.ToLower(stop.StopName)
		v.SetMetadata(stop)
		graph.AddVertex(v)
	}
	logMem("after stops")

	stopTimeMap := make(map[string][]compactStopTime, 150000)
	if err := buildStopTimeMap(stopTimesArg, stopTimeMap); err != nil {
		return err
	}
	logMem("after stopTimeMap")

	// Pre-assign intern IDs from map keys — keys are already deduplicated trip IDs.
	tripIntern := make(map[string]uint32, len(stopTimeMap))
	var nextTripID uint32 = 1
	for tripID := range stopTimeMap {
		tripIntern[tripID] = nextTripID
		nextTripID++
	}

	n := 0
	for tripID, times := range stopTimeMap {
		sort.Slice(times, func(i, j int) bool {
			return times[i].StopSequence < times[j].StopSequence
		})
		tid := tripIntern[tripID]
		delete(stopTimeMap, tripID) // release slice backing array progressively
		for i := 0; i < len(times)-1; i++ {
			from := times[i]
			to := times[i+1]
			fromV := graph.GetVertexByID(from.StopID)
			toV := graph.GetVertexByID(to.StopID)
			if fromV == nil || toV == nil {
				continue
			}
			props := EdgeProperties{
				TripID:       tid,
				Departure:    from.Departure,
				Arrival:      to.Arrival,
				TransferType: COMMUTE_EDGE,
			}
			if _, err := graph.AddEdge(fromV, toV, props); err != nil {
				return err
			}
		}
		n++
		if n%20000 == 0 {
			runtime.GC()
		}
	}
	logMem("after commute edges")
	if err := graph.addTransferEdges(stops); err != nil {
		return err
	}
	runtime.GC()
	logMem("after transfer edges+GC")
	return nil
}

func (graph *SLGraph) addTransferEdges(stops []*Stop) error {
	for i, a := range stops {
		if a.LocationType != "0" {
			continue
		}
		for j, b := range stops {
			if i >= j {
				continue
			}
			if b.LocationType != "0" {
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
					Departure:    0,
					Arrival:      int16(walkMinutes),
					TransferType: WALK_EDGE,
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

// buildStopTimeMap streams stop_times CSV files one at a time into stopTimeMap,
// converting times to int16 minutes immediately and GC'ing between files.
func buildStopTimeMap(arg string, stopTimeMap map[string][]compactStopTime) error {
	info, err := os.Stat(arg)
	if err != nil {
		return err
	}
	var paths []string
	if info.IsDir() {
		paths, err = filepath.Glob(filepath.Join(arg, "sl_stop_times_part*.csv"))
		if err != nil {
			return err
		}
		sort.Strings(paths)
	} else {
		paths = []string{arg}
	}
	for _, p := range paths {
		chunk, err := loadCSV[StopTimes](p)
		if err != nil {
			return fmt.Errorf("loading %s: %w", p, err)
		}
		for _, st := range chunk {
			stopTimeMap[st.TripID] = append(stopTimeMap[st.TripID], compactStopTime{
				StopID:       st.StopID,
				StopSequence: int16(st.StopSequence),
				Departure:    int16(toMinutes(st.DepartureTime)),
				Arrival:      int16(toMinutes(st.ArrivalTime)),
			})
		}
		chunk = nil
		runtime.GC()
		logMem("after file " + p)
	}
	return nil
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
