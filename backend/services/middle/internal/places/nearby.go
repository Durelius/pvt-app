package nearby

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/durelius/pvt-app/backend/services/middle/internal/location"
)

const placesURL = "https://places.googleapis.com/v1/places:searchNearby"

type NearbySearchRequest struct {
	IncludedTypes       []string            `json:"includedTypes"`
	MaxResultCount      int                 `json:"maxResultCount"`
	LocationRestriction LocationRestriction `json:"locationRestriction"`
}

type LocationRestriction struct {
	Circle Circle `json:"circle"`
}

type Circle struct {
	Center LatLng  `json:"center"`
	Radius float64 `json:"radius"`
}

type LatLng struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type PlacesResponse struct {
	Places []Place `json:"places"`
}

type Place struct {
	DisplayName      LocalizedText `json:"displayName"`
	FormattedAddress string        `json:"formattedAddress"`
	Rating           float64       `json:"rating"`
}

type LocalizedText struct {
	Text string `json:"text"`
}

func Nearby(point location.Point, locationType string) ([]Place, error) {

	reqBody := NearbySearchRequest{
		IncludedTypes:  []string{locationType},
		MaxResultCount: 5,
		LocationRestriction: LocationRestriction{
			Circle: Circle{
				Center: LatLng{Latitude: point.Latitude, Longitude: point.Longitude},
				Radius: 1000,
			},
		},
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, placesURL, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", apiKey)
	req.Header.Set("X-Goog-FieldMask", "places.displayName,places.formattedAddress,places.rating")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, b)
	}

	var result PlacesResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	return result.Places, nil
}
