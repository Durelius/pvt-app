package search_test

import (
	"testing"

	"github.com/durelius/pvt-app/backend/services/sl/internal/searchaddress"
)

func TestSearchAddressAddress(t *testing.T) {
	data, err := searchaddress.AddressSearch("Värtavägen 23, stockholm", "Frescativägen 16, Stockholm")
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}

func TestSearchAddressId(t *testing.T) {
	data, err := searchaddress.AddressSearch("Frescativägen 16, Stockholm", "9091001000009192")
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}

func TestSearchIdId(t *testing.T) {
	data, err := searchaddress.AddressSearch("9091001000009182", "9091001000009192")
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}

func TestSearchCoord(t *testing.T) {
	data, err := searchaddress.AddressSearch("18.013809:59.335104:WGS84[dd.ddddd]", "18.055816:59.364513:WGS84[dd.ddddd]", true)
	if err != nil {
		t.Errorf("Error getting address: %v", err)
	}

	t.Logf("Data returned: %+v", data)
}
