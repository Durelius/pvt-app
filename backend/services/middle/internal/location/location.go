package location

import (
	"fmt"
	"log"

	"github.com/durelius/pvt-app/backend/services/middle/internal/geocoding"
)

type Point struct {
	Latitude  float64 `json:"lat"`
	Longitude float64 `json:"lon"`
}
type Address struct {
	Street string `json:"street"` //example: Råstensgatan 2
	Zip    string `json:"zip"`    //example: 17270
	City   string `json:"city"`   //example: Sundbyberg
}

func (a *Address) Point() (*Point, error) {
	if len(a.Street) == 0 || len(a.Zip) == 0 || len(a.City) == 0 {
		return nil, fmt.Errorf("Street, city or zip is empty")
	}

	log.Println(a.City)
	log.Println(a.Street)
	log.Println(a.Zip)
	lat, lon, err := geocoding.AddressSearch(a.Street, a.City, a.Zip)
	if err != nil {
		return nil, err
	}
	return &Point{lat, lon}, nil
}
func (p *Point) ClosestAddress() (*Address, error) {
	if p.Latitude == 0 || p.Longitude == 0 {
		return nil, fmt.Errorf("Latitude or longitude is zero")
	}

	address, zip, city, err := geocoding.PointSearch(p.Latitude, p.Longitude)
	if err != nil {
		return nil, err
	}
	return &Address{address, zip, city}, nil
}
