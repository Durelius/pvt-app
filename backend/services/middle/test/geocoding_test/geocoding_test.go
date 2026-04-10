package geocoding_test

import (
	"testing"

	"github.com/durelius/pvt-app/backend/services/middle/internal/geocoding"
	"github.com/durelius/pvt-app/backend/services/middle/internal/location"
)

// Råstensgatan 2, sumpan
var sumpan = location.Point{Latitude: 59.36190155572168, Longitude: 17.973128182944045}

func TestCoordinateToAddress(t *testing.T) {

	_, _, _, err := geocoding.PointSearch(sumpan.Latitude, sumpan.Longitude)
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

}
func TestAddressToCoordinate(t *testing.T) {

	_, _, err := geocoding.AddressSearch("Råstensgatan 2", "172 70", "Sundbyberg")
	if err != nil {
		t.Errorf("Error getting coordinate: %v", err)
	}

}
