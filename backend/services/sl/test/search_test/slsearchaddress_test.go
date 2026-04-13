package search_test

import (
	"testing"

	"github.com/durelius/pvt-app/backend/services/sl/internal/searchaddress"
	"github.com/durelius/pvt-app/backend/shared/models/location"
)

var ADRESS_ONE = location.Address{Street: "Värtavägen 23", City: "Stockholm", Zip: "115 53"}
var ADDRESS_TWO = location.Address{Street: "Frescativägen 16", City: "Stockholm", Zip: "104 05"}

var ID_ONE = "9091001000009182"
var ID_TWO = "9091001000009192"

var COORD_ONE = location.Point{Latitude: 18.013809, Longitude: 59.335104}
var COORD_TWO = location.Point{Latitude: 18.055816, Longitude: 59.364513}

func TestSearchAddress(t *testing.T) {
	data, err := searchaddress.AddressSearch(ADRESS_ONE, ADDRESS_TWO)
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}

// func TestSearchAddressId(t *testing.T) {
// 	data, err := searchaddress.AddressSearch("Frescativägen 16, Stockholm", "9091001000009192")
// 	if err != nil {
// 		t.Errorf("Error getting address: %v", err)
// 	}
//
// 	t.Logf("Data returned: %+v", data)
// }

func TestSearchId(t *testing.T) {
	data, err := searchaddress.IDSearch(ID_ONE, ID_TWO)
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}

func TestSearchCoord(t *testing.T) {
	data, err := searchaddress.PointSearch(COORD_ONE, COORD_TWO)
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}
