package searchaddress

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"

	"github.com/durelius/pvt-app/backend/shared/models/location"
)

type SLTripResponse struct {
	Journeys []struct {
		Duration int `json:"tripDuration"`

		Legs []struct {
			Origin struct {
				Name string `json:"name"`
			} `json:"origin"`
			Transportation struct {
				Name string `json:"name"`
			} `json:"transportation"`
		} `json:"legs"`
	} `json:"journeys"`
}

const TARGET = "https://journeyplanner.integration.sl.se/v2/trips?type_origin=%s&type_sf=%s&name_origin=%s&type_destination=%s&name_destination=%s&calc_number_of_trips=3"

func AddressSearch(tripOrigin, tripDestination location.Address) (*SLTripResponse, error) {
	type_origin := "any"
	type_sf := "any"
	type_destination := "any"
	from := fmt.Sprintf("%s, %s", tripOrigin.Street, tripOrigin.City)
	to := fmt.Sprintf("%s, %s", tripDestination.Street, tripDestination.City)
	query := fmt.Sprintf(TARGET, type_origin, type_sf, url.QueryEscape(from), type_destination, url.QueryEscape(to))
	log.Print(query)
	req, err := http.NewRequest("GET", query, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", "MITTEN")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var tripData SLTripResponse

	if err := json.NewDecoder(resp.Body).Decode(&tripData); err != nil {
		return nil, fmt.Errorf("failed to decode JSON: %w", err)
	}

	return &tripData, nil
}
func IDSearch(tripOrigin, tripDestination string) (*SLTripResponse, error) {
	type_origin := "any"
	type_sf := "any"
	type_destination := "any"
	query := fmt.Sprintf(TARGET, type_origin, type_sf, url.QueryEscape(tripOrigin), type_destination, url.QueryEscape(tripDestination))
	log.Print(query)
	req, err := http.NewRequest("GET", query, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", "MITTEN")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var tripData SLTripResponse

	if err := json.NewDecoder(resp.Body).Decode(&tripData); err != nil {
		return nil, fmt.Errorf("failed to decode JSON: %w", err)
	}

	return &tripData, nil
}
func PointSearch(tripOrigin, tripDestination location.Point) (*SLTripResponse, error) {
	type_origin := "coord"
	type_sf := "coord"
	type_destination := "coord"
	from := fmt.Sprintf("%f:%f", tripOrigin.Latitude, tripOrigin.Longitude)
	to := fmt.Sprintf("%f:%f", tripDestination.Latitude, tripDestination.Longitude)
	query := fmt.Sprintf(TARGET, type_origin, type_sf, url.QueryEscape(from), type_destination, url.QueryEscape(to))
	log.Print(query)
	req, err := http.NewRequest("GET", query, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("User-Agent", "MITTEN")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var tripData SLTripResponse

	if err := json.NewDecoder(resp.Body).Decode(&tripData); err != nil {
		return nil, fmt.Errorf("failed to decode JSON: %w", err)
	}

	return &tripData, nil
}
