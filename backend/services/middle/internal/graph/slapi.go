package graph

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

var slClient = &http.Client{Timeout: 5 * time.Second}

type slTripResponse struct {
	Journeys []struct {
		Duration int `json:"tripDuration"`
	} `json:"journeys"`
}

const slJourneyPlannerURL = "https://journeyplanner.integration.sl.se/v2/trips?type_origin=%s&name_origin=%s&type_destination=%s&name_destination=%s&calc_number_of_trips=3"

// slPointSearch calls the SL Journey Planner API with coordinates and returns travel time in minutes.
// Coordinates must be in WGS84 and are formatted as "lon:lat:WGS84[dd.ddddd]" per API spec.
func slPointSearch(fromLat, fromLon, toLat, toLon float64) (int, error) {
	from := fmt.Sprintf("%f:%f:WGS84[dd.ddddd]", fromLon, fromLat)
	to := fmt.Sprintf("%f:%f:WGS84[dd.ddddd]", toLon, toLat)
	query := fmt.Sprintf(slJourneyPlannerURL, "coord", url.QueryEscape(from), "coord", url.QueryEscape(to))

	req, err := http.NewRequest("GET", query, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("User-Agent", "MITTEN")

	resp, err := slClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var data slTripResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, fmt.Errorf("decode: %w", err)
	}
	if len(data.Journeys) == 0 {
		return 0, fmt.Errorf("no journeys returned")
	}
	return data.Journeys[0].Duration / 60, nil
}
