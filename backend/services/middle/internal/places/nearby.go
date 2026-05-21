package places

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"github.com/durelius/pvt-app/backend/shared/models/location"
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
	ID                  string        `json:"id"`
	DisplayName         LocalizedText `json:"displayName"`
	FormattedAddress    string        `json:"formattedAddress"`
	Location            LatLng        `json:"location"`
	Types               []string      `json:"types"`
	PrimaryType         string        `json:"primaryType"`
	Photos              []Photo       `json:"photos"`

	/** Pro tools
	Rating              float64       `json:"rating"`
	PhoneNumber         string        `json:"internationalPhoneNumber"`
	WebsiteURI          string        `json:"websiteUri"`
	PriceLevel          string        `json:"priceLevel"`
	UserRatingCount     int           `json:"userRatingCount"`
	CurrentOpeningHours OpeningHours  `json:"currentOpeningHours"`
	RegularOpeningHours OpeningHours  `json:"regularOpeningHours"`
	Reviews             []Review      `json:"reviews"`
	EditorialSummary    LocalizedText `json:"editorialSummary"`
	Takeout             bool          `json:"takeout"`
	Delivery            bool          `json:"delivery"`
	DineIn              bool          `json:"dineIn"`
	GoodForChildren     bool          `json:"goodForChildren"`
	OutdoorSeating      bool          `json:"outdoorSeating"`
	LiveMusic           bool          `json:"liveMusic"`
	ServesCoffee        bool          `json:"servesCoffee"`
	ServesBreakfast     bool          `json:"servesBreakfast"`
	ServesLunch         bool          `json:"servesLunch"`
	ServesDinner        bool          `json:"servesDinner"`
	ServesBeer          bool          `json:"servesBeer"`
	AccessibilityOptions AccessInfo   `json:"accessibilityOptions"` 
	**/
}

type LocalizedText struct {
	Text string `json:"text"`
}

type OpeningHours struct {
	OpenNow             bool     `json:"openNow"`
	WeekdayDescriptions []string `json:"weekdayDescriptions"`
	Periods             []Period `json:"periods"`
}

type Period struct {
	Open  TimeOfDay `json:"open"`
	Close TimeOfDay `json:"close"`
}

type TimeOfDay struct {
	Day    int `json:"day"`
	Hour   int `json:"hour"`
	Minute int `json:"minute"`
}

type Photo struct {
	Name               string        `json:"name"`
	WidthPx            int           `json:"widthPx"`
	HeightPx           int           `json:"heightPx"`
	AuthorAttributions []Attribution `json:"authorAttributions"`
}

type Review struct {
	Name              string        `json:"name"`
	Rating            int           `json:"rating"`
	Text              LocalizedText `json:"text"`
	PublishTime       string        `json:"publishTime"`
	AuthorAttribution Attribution   `json:"authorAttribution"`
}

type Attribution struct {
	DisplayName string `json:"displayName"`
	URI         string `json:"uri"`
	PhotoURI    string `json:"photoUri"`
}

type AccessInfo struct {
	WheelchairAccessibleParking  bool `json:"wheelchairAccessibleParking"`
	WheelchairAccessibleEntrance bool `json:"wheelchairAccessibleEntrance"`
	WheelchairAccessibleRestroom bool `json:"wheelchairAccessibleRestroom"`
	WheelchairAccessibleSeating  bool `json:"wheelchairAccessibleSeating"`
}

const fieldMask = "places.id,places.displayName,places.formattedAddress," +
    "places.location,places.types,places.primaryType,places.photos"

func Nearby(point location.Point, locationType string, radiusMeters float64) ([]Place, error) {
	apiKey := os.Getenv("PLACES_KEY")

	reqBody := NearbySearchRequest{
		IncludedTypes:  []string{locationType},
		MaxResultCount: 20,
		LocationRestriction: LocationRestriction{
			Circle: Circle{
				Center: LatLng{Latitude: point.Latitude, Longitude: point.Longitude},
				Radius: radiusMeters,
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
	fmt.Println("FieldMask:", req.Header.Get("X-Goog-FieldMask"))
	req.Header.Set("X-Goog-FieldMask", fieldMask)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, b)
	}
	// TEMPORÄR LOGGING - ta bort sen
	b, _ := io.ReadAll(resp.Body)
	fmt.Println("RAW GOOGLE RESPONSE:", string(b))
	resp.Body = io.NopCloser(bytes.NewReader(b))
	// SLUT LOGGING

	var result PlacesResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	return result.Places, nil
}