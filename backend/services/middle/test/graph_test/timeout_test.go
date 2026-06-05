package graph_test

import (
	"context"
	"testing"
	"time"
)

// TestAllTravelTimesFrom_FullResult verifies att ett normalt anrop returnerar
// ett komplett resultat med complete=true och ett icke-tomt stopmap.
func TestAllTravelTimesFrom_FullResult(t *testing.T) {
	gr := loadGraph(t)
	stops := gr.FindStopsByName("t-centralen")
	if len(stops) == 0 {
		t.Skip("t-centralen not found in data")
	}

	ctx := context.Background()
	result, complete := gr.AllTravelTimesFrom(ctx, stops[0], startTime)

	if !complete {
		t.Error("expected complete=true with unlimited context, got false")
	}
	if len(result) == 0 {
		t.Error("expected non-empty result map")
	}
}

// TestAllTravelTimesFrom_TimeoutReturnsPartial verifies att en redan-avbruten
// context returnerar complete=false men ändå ett (eventuellt tomt) map utan panic.
func TestAllTravelTimesFrom_TimeoutReturnsPartial(t *testing.T) {
	gr := loadGraph(t)
	// Använd ett stopp som inte används i andra tester för att undvika cache-träff
	stops := gr.FindStopsByName("mörby centrum")
	if len(stops) == 0 {
		t.Skip("mörby centrum not found in data")
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// Om cache-träff: hoppa över testet, det är ett separat beteende som
	// täcks av TestAllTravelTimesFrom_CacheHitAlwaysComplete
	result, complete := gr.AllTravelTimesFrom(ctx, stops[0], startTime)
	if complete {
		t.Skip("cache hit – cancellation behaviour tested in CacheHitAlwaysComplete")
	}

	if result == nil {
		t.Error("expected non-nil map even on timeout")
	}
}

// TestAllTravelTimesFrom_VeryShortTimeout verifies att en extremt kort deadline
// returnerar complete=false och ett partiellt (icke-nil) resultat.
func TestAllTravelTimesFrom_VeryShortTimeout(t *testing.T) {
	gr := loadGraph(t)
	stops := gr.FindStopsByName("fridhemsplan")
	if len(stops) == 0 {
		t.Skip("fridhemsplan not found in data")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
	defer cancel()

	// Låt timeout hinna löpa ut
	time.Sleep(5 * time.Millisecond)

	result, complete := gr.AllTravelTimesFrom(ctx, stops[0], startTime)

	if complete {
		t.Error("expected complete=false with 1ns timeout, got true")
	}
	if result == nil {
		t.Error("expected non-nil map even on timeout")
	}
}

// TestAllTravelTimesFrom_PartialResultsAreValid verifies att partiella resultat
// håller sig inom maxTravelMinutes – inga orimliga värden ska smita igenom.
func TestAllTravelTimesFrom_PartialResultsAreValid(t *testing.T) {
	gr := loadGraph(t)
	stops := gr.FindStopsByName("odenplan")
	if len(stops) == 0 {
		t.Skip("odenplan not found in data")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	result, _ := gr.AllTravelTimesFrom(ctx, stops[0], startTime)

	for stopIdx, minutes := range result {
		if minutes < 0 || minutes > 60 {
			t.Errorf("stop %d: travel time %d min outside valid range [0, 60]", stopIdx, minutes)
		}
	}
}

// TestAllTravelTimesFrom_CacheHitAlwaysComplete verifies att ett cachat resultat
// alltid returnerar complete=true, även om contexten är avbruten.
func TestAllTravelTimesFrom_CacheHitAlwaysComplete(t *testing.T) {
	gr := loadGraph(t)
	stops := gr.FindStopsByName("slussen")
	if len(stops) == 0 {
		t.Skip("slussen not found in data")
	}

	// Första anropet – fyller cachen
	ctx := context.Background()
	_, firstComplete := gr.AllTravelTimesFrom(ctx, stops[0], startTime)
	if !firstComplete {
		t.Skip("first call was partial, cache not populated – skipping cache test")
	}

	// Andra anropet med avbruten context – ska ändå returnera complete=true från cache
	cancelled, cancel := context.WithCancel(context.Background())
	cancel()

	_, complete := gr.AllTravelTimesFrom(cancelled, stops[0], startTime)
	if !complete {
		t.Error("expected complete=true on cache hit even with cancelled context")
	}
}