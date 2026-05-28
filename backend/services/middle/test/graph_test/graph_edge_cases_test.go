package graph_test

import (
	"testing"

	"github.com/durelius/pvt-app/backend/services/middle/internal/graph"
)

// routePairs are stop-name pairs used across multiple tests.
var routePairs = [][2]string{
	{"t-centralen", "slussen"},
	{"fridhemsplan", "gamla stan"},
	{"mörby centrum", "fruängen"},
}

// --- TravelMinutes correctness ---

// TestTravelMinutes_NeverNegativeWhenRouteFound is a regression test for the
// bug where walk-edge Metadata.Arrival (a relative duration) was subtracted
// from startTime as though it were an absolute clock time, yielding large
// negative results.
func TestTravelMinutes_NeverNegativeWhenRouteFound(t *testing.T) {
	gr := loadGraph(t)
	for _, pair := range routePairs {
		froms := gr.FindStopsByName(pair[0])
		tos := gr.FindStopsByName(pair[1])
		if len(froms) == 0 || len(tos) == 0 {
			t.Logf("skipping %s→%s: stops not found", pair[0], pair[1])
			continue
		}
		m := gr.TravelMinutes(froms[0], tos[0], startTime)
		if m < 0 {
			t.Errorf("%s→%s: TravelMinutes=%d (negative)", pair[0], pair[1], m)
		}
	}
}

// TestTravelMinutes_CachingIsIdempotent verifies two calls for the same pair
// return the same result.
func TestTravelMinutes_CachingIsIdempotent(t *testing.T) {
	gr := loadGraph(t)
	froms := gr.FindStopsByName("fridhemsplan")
	tos := gr.FindStopsByName("gamla stan")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found")
	}
	m1 := gr.TravelMinutes(froms[0], tos[0], startTime)
	m2 := gr.TravelMinutes(froms[0], tos[0], startTime)
	if m1 != m2 {
		t.Errorf("TravelMinutes not idempotent: first=%d second=%d", m1, m2)
	}
}

// --- FindRoute path invariants ---

// TestFindRoute_NoConsecutiveWalks verifies the hasWalked constraint:
// the A* algorithm must board transit before allowing a second walk.
func TestFindRoute_NoConsecutiveWalks(t *testing.T) {
	gr := loadGraph(t)
	for _, pair := range routePairs {
		froms := gr.FindStopsByName(pair[0])
		tos := gr.FindStopsByName(pair[1])
		if len(froms) == 0 || len(tos) == 0 {
			continue
		}
		path := gr.FindRoute(froms[0], tos[0], startTime)
		for i := 1; i < len(path); i++ {
			if path[i-1].Metadata.TransferType == graph.WALK_EDGE &&
				path[i].Metadata.TransferType == graph.WALK_EDGE {
				t.Errorf("%s→%s: consecutive walk edges at positions %d and %d", pair[0], pair[1], i-1, i)
			}
		}
	}
}

// TestFindRoute_PathIsConnected verifies that consecutive edges share a stop:
// edge[i].Destination must equal edge[i+1].Source.
func TestFindRoute_PathIsConnected(t *testing.T) {
	gr := loadGraph(t)
	for _, pair := range routePairs {
		froms := gr.FindStopsByName(pair[0])
		tos := gr.FindStopsByName(pair[1])
		if len(froms) == 0 || len(tos) == 0 {
			continue
		}
		path := gr.FindRoute(froms[0], tos[0], startTime)
		for i := 1; i < len(path); i++ {
			prev := path[i-1].Destination()
			curr := path[i].Source()
			if prev.StopID != curr.StopID {
				t.Errorf("%s→%s edge %d→%d: dest stop %s ≠ next source stop %s",
					pair[0], pair[1], i-1, i, prev.StopID, curr.StopID)
			}
		}
	}
}

// TestFindRoute_EdgesAreTemporallyConsistent verifies that each commute edge
// in the returned path departs no earlier than the previous edge arrived.
// This catches cases where the path reconstruction re-orders edges.
func TestFindRoute_EdgesAreTemporallyConsistent(t *testing.T) {
	gr := loadGraph(t)
	for _, pair := range routePairs {
		froms := gr.FindStopsByName(pair[0])
		tos := gr.FindStopsByName(pair[1])
		if len(froms) == 0 || len(tos) == 0 {
			continue
		}
		path := gr.FindRoute(froms[0], tos[0], startTime)
		prevArrival := startTime
		for i, e := range path {
			if e.Metadata.TransferType == graph.COMMUTE_EDGE {
				if int(e.Metadata.Departure) < prevArrival {
					t.Errorf("%s→%s edge %d: departure %d < previous arrival %d",
						pair[0], pair[1], i, e.Metadata.Departure, prevArrival)
				}
				prevArrival = int(e.Metadata.Arrival)
			} else {
				// walk: arrival is duration, not absolute time
				prevArrival += int(e.Metadata.Arrival) + 5
			}
		}
	}
}

// TestFindRoute_WalkEdgesHaveExpectedProperties verifies the invariants that
// addTransferEdges must satisfy: Departure=0, Arrival=walkDuration>0, TripID=0.
func TestFindRoute_WalkEdgesHaveExpectedProperties(t *testing.T) {
	gr := loadGraph(t)
	// T-Centralen → Slussen reliably produces a path with a trailing walk edge.
	froms := gr.FindStopsByName("t-centralen")
	tos := gr.FindStopsByName("slussen")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found")
	}
	path := gr.FindRoute(froms[0], tos[0], startTime)
	if len(path) == 0 {
		t.Skip("no path found")
	}
	for i, e := range path {
		if e.Metadata.TransferType != graph.WALK_EDGE {
			continue
		}
		if e.Metadata.Departure != 0 {
			t.Errorf("walk edge %d: Departure=%d, want 0", i, e.Metadata.Departure)
		}
		if e.Metadata.Arrival <= 0 {
			t.Errorf("walk edge %d: Arrival=%d, want >0", i, e.Metadata.Arrival)
		}
		if e.Metadata.TripID != 0 {
			t.Errorf("walk edge %d: TripID=%d, want 0", i, e.Metadata.TripID)
		}
	}
}

// TestFindRoute_MultiTripRoute verifies that a long cross-city route uses
// more than one distinct transit trip, confirming that trip interning and
// transfer detection both work correctly end-to-end.
func TestFindRoute_MultiTripRoute(t *testing.T) {
	gr := loadGraph(t)
	froms := gr.FindStopsByName("mörby centrum")
	tos := gr.FindStopsByName("fruängen")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found")
	}
	path := gr.FindRoute(froms[0], tos[0], startTime)
	if len(path) == 0 {
		t.Fatal("expected a path for Mörby centrum → Fruängen")
	}
	seen := map[uint32]bool{}
	for _, e := range path {
		if e.Metadata.TripID != 0 {
			seen[e.Metadata.TripID] = true
		}
	}
	if len(seen) < 2 {
		t.Errorf("expected ≥2 distinct trip IDs for a cross-city route, got %d", len(seen))
	}
}

// TestFindRoute_LateNight verifies that routing at 23:55 either returns nil
// (no service) or a temporally valid path. It must not panic or return
// a path with edges that are impossible to board.
func TestFindRoute_LateNight(t *testing.T) {
	gr := loadGraph(t)
	froms := gr.FindStopsByName("t-centralen")
	tos := gr.FindStopsByName("odenplan")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found")
	}
	lateTime := 23*60 + 55
	path := gr.FindRoute(froms[0], tos[0], lateTime)
	if path == nil {
		return // no service at this hour is valid
	}
	prevArrival := lateTime
	for i, e := range path {
		if e.Metadata.TransferType == graph.COMMUTE_EDGE {
			if int(e.Metadata.Departure) < prevArrival {
				t.Errorf("late-night edge %d: departure %d < previous arrival %d",
					i, e.Metadata.Departure, prevArrival)
			}
			prevArrival = int(e.Metadata.Arrival)
		} else {
			prevArrival += int(e.Metadata.Arrival) + 5
		}
	}
}

// --- Stop filtering: only location_type=0 should appear in the graph ---

// TestFindStopsByName_ReturnsOnlyBoardingStops verifies that search results
// never include parent stations (type 1) or entrance nodes (type 2) such as
// the "Södermalmstorg" entrance that was incorrectly appearing near Slussen.
func TestFindStopsByName_ReturnsOnlyBoardingStops(t *testing.T) {
	gr := loadGraph(t)
	for _, name := range []string{"slussen", "t-centralen", "odenplan", "fridhemsplan"} {
		for _, v := range gr.FindStopsByName(name) {
			if v.Metadata().LocationType != "0" {
				t.Errorf("FindStopsByName(%q) returned stop %s with LocationType=%q (want \"0\")",
					name, v.Metadata().StopID, v.Metadata().LocationType)
			}
		}
	}
}

// TestFindNClosestStops_BoundedAndPlatformsOnly verifies that FindNClosestStops
// respects the N limit and never returns non-boarding stops.
func TestFindNClosestStops_BoundedAndPlatformsOnly(t *testing.T) {
	gr := loadGraph(t)
	const N = 5
	stops := gr.FindNClosestStops(59.3314, 18.0587, N) // T-Centralen area
	if len(stops) == 0 {
		t.Fatal("expected stops near T-Centralen, got none")
	}
	if len(stops) > N {
		t.Errorf("expected at most %d stops, got %d", N, len(stops))
	}
	for _, v := range stops {
		if v.Metadata().LocationType != "0" {
			t.Errorf("FindNClosestStops returned non-platform stop %s (type %q)",
				v.Metadata().StopID, v.Metadata().LocationType)
		}
	}
}

// TestFindStopsWithinRadius_ReturnsOnlyPlatforms verifies that radius search
// does not include entrance or station nodes.
func TestFindStopsWithinRadius_ReturnsOnlyPlatforms(t *testing.T) {
	gr := loadGraph(t)
	stops := gr.FindStopsWithinRadius(59.3198, 18.0718, 300) // Slussen area, 300m
	if len(stops) == 0 {
		t.Fatal("expected stops within 300m of Slussen, got none")
	}
	for _, v := range stops {
		if v.Metadata().LocationType != "0" {
			t.Errorf("FindStopsWithinRadius returned non-platform stop %s (type %q)",
				v.Metadata().StopID, v.Metadata().LocationType)
		}
	}
}
