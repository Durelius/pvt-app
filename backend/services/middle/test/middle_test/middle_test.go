package middletest

import (
	"testing"

	"github.com/durelius/pvt-app/backend/services/middle/internal/middle"
	"github.com/durelius/pvt-app/backend/shared/models/location"
)

// Råstensgatan 2, sumpan
var sumpan = location.Point{Latitude: 59.36190155572168, Longitude: 17.973128182944045}

// Vallavägen 165, handen
var handen = location.Point{Latitude: 59.1621452647144, Longitude: 18.14974437129048}

// linnegatan 60, östermalm
var rich = location.Point{Latitude: 59.335724925744856, Longitude: 18.087293871298627}

var points = []location.Point{sumpan, handen, rich}

func TestAverageMiddlePoint(t *testing.T) {
	average, err := middle.Average(points)
	if err != nil {
		t.Errorf("Error getting average: %v", err)
	}
	expectedMiddle := location.Point{Latitude: 59.286591, Longitude: 18.070055}
	if *average != expectedMiddle {
		t.Errorf("Average return (%v) is not same as expected average (%v).", *average, expectedMiddle)
	}

}
func TestMedianMiddlePoint(t *testing.T) {

	median, err := middle.Median(points)
	if err != nil {
		t.Errorf("Error getting median: %v", err)
	}
	expectedMedian := location.Point{Latitude: 59.335725, Longitude: 18.087294}
	if *median != expectedMedian {
		t.Errorf("Median return (%v) is not same as expected median (%v).", *median, expectedMedian)
	}

}
