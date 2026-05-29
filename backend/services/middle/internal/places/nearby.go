package places

import (
	"net/url"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	plog "github.com/durelius/go-prodlog"
	"github.com/durelius/pvt-app/backend/shared/models/location"
)


const placesURL = "https://places.googleapis.com/v1/places:searchNearby"

var overpassClient = &http.Client{Timeout: 5 * time.Second}
var mapboxClient = &http.Client{Timeout: 3 * time.Second}

// Overpass public instances tried in order on failure.
var overpassEndpoints = []string{
	"https://overpass-api.de/api/interpreter",
	"https://overpass.kumi.systems/api/interpreter",
	"https://overpass.openstreetmap.ru/api/interpreter",
}

// ---- Place model ----

type Place struct {
	ID               string        `json:"id"`
	DisplayName      LocalizedText `json:"displayName"`
	FormattedAddress string        `json:"formattedAddress"`
	Rating           float64       `json:"rating"` // heuristic 0–10
	Location         LatLng        `json:"location"`

	// OSM tags — free, extracted from the Overpass response we already fetch
	OpeningHours   string `json:"openingHours,omitempty"`
	Phone          string `json:"phone,omitempty"`
	Website        string `json:"website,omitempty"`
	Cuisine        string `json:"cuisine,omitempty"`
	OutdoorSeating bool   `json:"outdoorSeating,omitempty"`
	Wheelchair     string `json:"wheelchair,omitempty"`
	DietVegan      bool   `json:"dietVegan,omitempty"`
	DietVegetarian bool   `json:"dietVegetarian,omitempty"`
	Wifi           bool   `json:"wifi,omitempty"`
	Smoking        string `json:"smoking,omitempty"`
	Dog            bool   `json:"dogFriendly,omitempty"`
	Takeaway       bool   `json:"takeaway,omitempty"`
	Organic        bool   `json:"organic,omitempty"`
	Noise          string `json:"-"`
	OSMAmenity     string `json:"-"`
}

type LocalizedText struct {
	Text string `json:"text"`
}

type LatLng struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// ---- Google Places (kept as fallback) ----

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

type PlacesResponse struct {
	Places []Place `json:"places"`
}

func NearbyGooglePlaces(point location.Point, locationType string, radiusMeters float64) ([]Place, error) {
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
	req.Header.Set("X-Goog-FieldMask", "places.id,places.displayName,places.formattedAddress,places.rating,places.location")

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

// ---- Overpass / OSM ----

type OverpassResponse struct {
	Elements []OverpassElement `json:"elements"`
}

type OverpassElement struct {
	Type   string            `json:"type"`
	ID     int64             `json:"id"`
	Lat    float64           `json:"lat"`
	Lon    float64           `json:"lon"`
	Center *OverpassCenter   `json:"center,omitempty"`
	Tags   map[string]string `json:"tags"`
}

type OverpassCenter struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

func NearbyOverPass(point location.Point, locationType string, radiusMeters float64) ([]Place, error) {
	return NearbyOverPassMulti([]location.Point{point}, locationType, radiusMeters)
}

func NearbyOverPassMulti(points []location.Point, locationType string, radiusMeters float64) ([]Place, error) {
	var sb strings.Builder
	sb.WriteString("[out:json][timeout:25];\n(\n")
	for _, p := range points {
		for _, tag := range []string{"amenity", "shop"} {
			fmt.Fprintf(&sb, "  node[\"%s\"=\"%s\"](around:%.0f,%.6f,%.6f);\n", tag, locationType, radiusMeters, p.Latitude, p.Longitude)
			fmt.Fprintf(&sb, "  way[\"%s\"=\"%s\"](around:%.0f,%.6f,%.6f);\n", tag, locationType, radiusMeters, p.Latitude, p.Longitude)
		}
	}
	sb.WriteString(");\nout center 100;\n")
	query := sb.String()

	var (
		result  OverpassResponse
		lastErr error
	)
	for _, endpoint := range overpassEndpoints {
		req, err := http.NewRequest(http.MethodPost, endpoint, strings.NewReader("data="+query))
		if err != nil {
			lastErr = err
			continue
		}
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		req.Header.Set("User-Agent", "pvt-app/1.0")

		resp, err := overpassClient.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("do request (%s): %w", endpoint, err)
			plog.Error(lastErr)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			b, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			lastErr = fmt.Errorf("API error %d from %s: %s", resp.StatusCode, endpoint, b)
			plog.Infof("overpass: %s returned %d, trying next endpoint", endpoint, resp.StatusCode)
			continue
		}

		err = json.NewDecoder(resp.Body).Decode(&result)
		resp.Body.Close()
		if err != nil {
			lastErr = fmt.Errorf("decode response: %w", err)
			continue
		}
		lastErr = nil
		break
	}
	if lastErr != nil {
		return nil, lastErr
	}

	type geocodeTask struct {
		idx int
		lat float64
		lon float64
	}

	ps := make([]Place, 0, len(result.Elements))
	var tasks []geocodeTask

	for _, el := range result.Elements {
		name := el.Tags["name"]
		if name == "" {
			continue
		}

		lat, lon := el.Lat, el.Lon
		if el.Type == "way" && el.Center != nil {
			lat, lon = el.Center.Lat, el.Center.Lon
		}

		idx := len(ps)
		ps = append(ps, Place{
			ID:               fmt.Sprintf("%s/%d", el.Type, el.ID),
			DisplayName:      LocalizedText{Text: name},
			FormattedAddress: buildOverpassAddress(el.Tags),
			Location:         LatLng{Latitude: lat, Longitude: lon},
			OpeningHours:     coalesce(el.Tags, "opening_hours"),
			Phone:            coalesce(el.Tags, "phone", "contact:phone"),
			Website:          coalesce(el.Tags, "website", "contact:website"),
			Cuisine:          el.Tags["cuisine"],
			OutdoorSeating:   el.Tags["outdoor_seating"] == "yes",
			Wheelchair:       el.Tags["wheelchair"],
			DietVegan:        el.Tags["diet:vegan"] == "yes",
			DietVegetarian:   el.Tags["diet:vegetarian"] == "yes",
			Wifi:             el.Tags["internet_access"] == "wlan" || el.Tags["wifi"] == "yes",
			Smoking:          el.Tags["smoking"],
			Dog:              el.Tags["dog"] == "yes",
			Takeaway:         el.Tags["takeaway"] == "yes",
			Organic:          el.Tags["organic"] == "yes",
			Noise:            el.Tags["noise"],
			OSMAmenity:       coalesce(el.Tags, "amenity", "shop"),
		})

		if ps[idx].FormattedAddress == "" {
			tasks = append(tasks, geocodeTask{idx, lat, lon})
		}
	}

	if len(tasks) > 0 {
		var wg sync.WaitGroup
		for _, t := range tasks {
			wg.Add(1)
			go func(t geocodeTask) {
				defer wg.Done()
				ps[t.idx].FormattedAddress = reverseGeocodeMapbox(t.lat, t.lon)
			}(t)
		}
		wg.Wait()
	}

	return ps, nil
}

func buildOverpassAddress(tags map[string]string) string {
	var parts []string
	if street := tags["addr:street"]; street != "" {
		if num := tags["addr:housenumber"]; num != "" {
			parts = append(parts, street+" "+num)
		} else {
			parts = append(parts, street)
		}
	}
	if city := tags["addr:city"]; city != "" {
		parts = append(parts, city)
	}
	if postcode := tags["addr:postcode"]; postcode != "" {
		parts = append(parts, postcode)
	}
	return strings.Join(parts, ", ")
}

func coalesce(tags map[string]string, keys ...string) string {
	for _, k := range keys {
		if v := tags[k]; v != "" {
			return v
		}
	}
	return ""
}

// ComputeHeuristicRating produces a 0–10 quality score for a meeting place
// using OSM tags and transit data. Higher = better meeting spot.
func ComputeHeuristicRating(p Place, transitSpread, transitAvg int) float64 {
	score := 0.0

	// Transit fairness (0–25 pts): lower spread + closer avg = better for everyone
	if transitSpread != math.MaxInt {
		score += math.Max(15-float64(transitSpread), 0)
		score += math.Max(10-float64(transitAvg)*0.5, 0)
	}

	// Accessibility
	switch p.Wheelchair {
	case "yes":
		score += 12
	case "limited":
		score += 5
	}
	if p.Wifi {
		score += 10
	}

	// Smoking environment
	switch p.Smoking {
	case "no":
		score += 10
	case "outside":
		score += 4
	case "yes":
		score -= 12
	case "dedicated_room":
		score -= 5
	}

	// Food inclusivity
	if p.DietVegan {
		score += 10
	}
	if p.DietVegetarian {
		score += 6
	}
	if p.Organic {
		score += 5
	}

	// Ambiance & flexibility
	if p.OutdoorSeating {
		score += 8
	}
	if p.Dog {
		score += 5
	}
	if p.Takeaway {
		score += 3
	}
	if p.Noise == "loud" {
		score -= 8
	}

	// Established & well-documented place
	if p.OpeningHours != "" {
		score += 5
	}
	if p.Website != "" {
		score += 4
	}
	if p.Phone != "" {
		score += 3
	}
	if p.Cuisine != "" {
		score += 3
	}

	// Penalty: places that are not appropriate meeting spots
	switch p.OSMAmenity {
	case "hospital", "clinic":
		score -= 30
	case "school", "college", "university":
		score -= 25
	case "police", "prison":
		score -= 30
	case "dentist", "doctors":
		score -= 20
	case "bank", "atm":
		score -= 15
	case "pharmacy":
		score -= 10
	case "fuel":
		score -= 15
	case "vending_machine":
		score -= 25
	}

	return math.Max(0, math.Min(10, score/45.0*10.0))
}

func haversineMeters(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371000.0
	φ1, φ2 := lat1*math.Pi/180, lat2*math.Pi/180
	Δφ := (lat2 - lat1) * math.Pi / 180
	Δλ := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(Δφ/2)*math.Sin(Δφ/2) + math.Cos(φ1)*math.Cos(φ2)*math.Sin(Δλ/2)*math.Sin(Δλ/2)
	return R * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

// Mapbox för adresser
func GeocodeAddress(query string) error {
	token := os.Getenv("MAPBOX_ACCESS_TOKEN")

	url := fmt.Sprintf(
		"https://api.mapbox.com/geocoding/v5/mapbox.places/%s.json?access_token=%s&limit=1",
		url.QueryEscape(query),
		token,
	)

	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	fmt.Println(string(body))
	return nil
}

func reverseGeocodeMapbox(lat, lon float64) string {
	token := os.Getenv("MAPBOX_ACCESS_TOKEN")
	if token == "" {
		return ""
	}

	u := fmt.Sprintf(
		"https://api.mapbox.com/geocoding/v5/mapbox.places/%f,%f.json?access_token=%s&limit=1",
		lon,
		lat,
		token,
	)

	resp, err := mapboxClient.Get(u)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	var result struct {
		Features []struct {
			PlaceName string `json:"place_name"`
		} `json:"features"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return ""
	}

	if len(result.Features) == 0 {
		return ""
	}

	return result.Features[0].PlaceName
}
