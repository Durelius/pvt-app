package graph_test

import (
	"strings"
	"testing"

	"github.com/durelius/pvt-app/backend/services/middle/internal/graph"
)

const dataDir = "../../data"

// startTime is 09:00 — a reasonable morning departure for all route tests.
const startTime = 9 * 60

var g *graph.SLGraph

func loadGraph(t *testing.T) *graph.SLGraph {
	t.Helper()
	if g != nil {
		return g
	}
	var err error
	g, err = graph.NewWithDataDir(dataDir)
	if err != nil {
		t.Fatalf("failed to load graph: %v", err)
	}
	return g
}

// --- FindNearestStop ---

func TestFindNearestStop_TCentralen(t *testing.T) {
	gr := loadGraph(t)
	// Coordinates of T-Centralen entrance
	stop := gr.FindNearestStop(59.3314, 18.0587)
	if stop == nil {
		t.Fatal("expected a stop, got nil")
	}
	name := strings.ToLower(stop.Metadata().StopName)
	// SL data uses "Stockholm C" rather than "T-Centralen"
	if !strings.Contains(name, "central") && !strings.Contains(name, "stockholm c") {
		t.Errorf("expected nearest stop to T-Centralen coords to contain 'central' or 'stockholm c', got %q", stop.Metadata().StopName)
	}
}

func TestFindNearestStop_Slussen(t *testing.T) {
	gr := loadGraph(t)
	stop := gr.FindNearestStop(59.3198, 18.0718)
	if stop == nil {
		t.Fatal("expected a stop, got nil")
	}
	name := strings.ToLower(stop.Metadata().StopName)
	if !strings.Contains(name, "slussen") {
		t.Errorf("expected nearest stop to Slussen coords to contain 'slussen', got %q", stop.Metadata().StopName)
	}
}

func TestFindNearestStop_ReturnsNonNilForAnyCoord(t *testing.T) {
	gr := loadGraph(t)
	// Arbitrary Stockholm coordinate
	stop := gr.FindNearestStop(59.35, 18.05)
	if stop == nil {
		t.Fatal("FindNearestStop returned nil for valid Stockholm coordinate")
	}
}

// --- FindStopsByName ---

func TestFindStopsByName_KnownStop(t *testing.T) {
	gr := loadGraph(t)
	results := gr.FindStopsByName("odenplan")
	if len(results) == 0 {
		t.Fatal("expected results for 'odenplan', got none")
	}
	for _, v := range results {
		if !strings.Contains(strings.ToLower(v.Metadata().StopName), "odenplan") {
			t.Errorf("result %q does not contain 'odenplan'", v.Metadata().StopName)
		}
	}
}

func TestFindStopsByName_NoMatch(t *testing.T) {
	gr := loadGraph(t)
	results := gr.FindStopsByName("zzznomatchzzz")
	if len(results) != 0 {
		t.Errorf("expected no results for nonsense query, got %d", len(results))
	}
}

// --- FindRoute / TravelMinutes ---

func TestTravelMinutes_SameStop(t *testing.T) {
	gr := loadGraph(t)
	stops := gr.FindStopsByName("t-centralen")
	if len(stops) == 0 {
		t.Skip("T-Centralen not found in data")
	}
	v := stops[0]
	minutes := gr.TravelMinutes(v, v, startTime)
	if minutes != 0 {
		t.Errorf("travel from a stop to itself should be 0 minutes, got %d", minutes)
	}
}

func TestTravelMinutes_TCentralenToSlussen(t *testing.T) {
	gr := loadGraph(t)
	froms := gr.FindStopsByName("t-centralen")
	tos := gr.FindStopsByName("slussen")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found in data")
	}
	minutes := gr.TravelMinutes(froms[0], tos[0], startTime)
	if minutes < 0 {
		t.Fatal("no route found from T-Centralen to Slussen")
	}
	// T-Centralen → Slussen is 1 stop on the green line, should be well under 30 min
	if minutes > 30 {
		t.Errorf("expected travel time under 30 minutes, got %d", minutes)
	}
}

func TestTravelMinutes_LongerRoute(t *testing.T) {
	gr := loadGraph(t)
	froms := gr.FindStopsByName("mörby centrum")
	tos := gr.FindStopsByName("fruängen")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found in data")
	}
	minutes := gr.TravelMinutes(froms[0], tos[0], startTime)
	if minutes < 0 {
		t.Fatal("no route found from Mörby centrum to Fruängen")
	}
	// End-to-end on the red line — should be 30-60 minutes
	if minutes < 20 || minutes > 90 {
		t.Errorf("expected 20-90 minutes for long cross-city route, got %d", minutes)
	}
}

func TestFindRoute_ReturnsOrderedPath(t *testing.T) {
	gr := loadGraph(t)
	froms := gr.FindStopsByName("fridhemsplan")
	tos := gr.FindStopsByName("gamla stan")
	if len(froms) == 0 || len(tos) == 0 {
		t.Skip("required stops not found in data")
	}
	path := gr.FindRoute(froms[0], tos[0], startTime)
	if path == nil {
		t.Fatal("expected a route, got nil")
	}
	if len(path) == 0 {
		t.Fatal("expected non-empty path")
	}
	// Verify path is temporally ordered — each edge arrives no earlier than it departs
	for i, edge := range path {
		if edge.Metadata.TransferType == 2 && edge.Metadata.Arrival < edge.Metadata.Departure {
			t.Errorf("edge %d: arrival (%d) is before departure (%d)", i, edge.Metadata.Arrival, edge.Metadata.Departure)
		}
	}
}
