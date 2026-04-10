package geocoding

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
)

const API_URL_ADDRESS_SEARCH = "https://nominatim.openstreetmap.org/search?street=%s&city=%s&postalcode=%s&countrycodes=se&format=json&limit=1&addressdetails=1"
const API_URL_REVERSE_SEARCH = "https://nominatim.openstreetmap.org/reverse?lat=%f&lon=%f&format=json&limit=1&addressdetails=1"

func AddressSearch(address, zip, city string) (latitude float64, longitude float64, err error) {
	query := fmt.Sprintf(API_URL_ADDRESS_SEARCH, url.QueryEscape(address), url.QueryEscape(city), url.QueryEscape(zip))
	req, err := http.NewRequest("GET", query, nil)
	if err != nil {
		return 0, 0, err
	}

	req.Header.Set("User-Agent", "MITTEN")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return 0, 0, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, 0, err
	}
	temps := []struct {
		Lat string `json:"lat"`
		Lon string `json:"lon"`
	}{}
	if err := json.Unmarshal(body, &temps); err != nil {
		return 0, 0, err
	}
	if len(temps) == 0 {
		return 0, 0, fmt.Errorf("no results")
	}
	temp := temps[0]
	lat, err := strconv.ParseFloat(temp.Lat, 64)
	if err != nil {
		return 0, 0, err
	}
	lon, err := strconv.ParseFloat(temp.Lon, 64)
	if err != nil {
		return 0, 0, err
	}
	return lat, lon, nil
}
func PointSearch(latitude, longitude float64) (address string, zip string, city string, err error) {
	query := fmt.Sprintf(API_URL_REVERSE_SEARCH, latitude, longitude)
	req, err := http.NewRequest("GET", query, nil)
	if err != nil {
		return "", "", "", err
	}

	req.Header.Set("User-Agent", "MITTEN")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", "", err
	}
	temp := struct {
		DisplayName string `json:"display_name"`
		Address     struct {
			Road         string `json:"road"`
			HouseNumber  string `json:"house_number"`
			Municipality string `json:"municipality"` // sometimes empty in Sweden
			Town         string `json:"town"`         // sometimes empty in Sweden
			City         string `json:"city"`         // sometimes empty in Sweden
			Village      string `json:"village"`      // sometimes empty in Sweden
			Postcode     string `json:"postcode"`
		} `json:"address"`
	}{}
	if err := json.Unmarshal(body, &temp); err != nil {
		return "", "", "", err
	}
	address = fmt.Sprintf("%s %s", temp.Address.Road, temp.Address.HouseNumber)
	zip = temp.Address.Postcode
	city = temp.Address.Municipality
	if city == "" {
		city = temp.Address.City
	}
	if city == "" {
		city = temp.Address.Town
	}
	if city == "" {
		city = temp.Address.Village
	}
	if len(address) == 0 || len(zip) == 0 || len(city) == 0 {
		return "", "", "", fmt.Errorf("A returned value of the API is empty. Returned values: [Road: %s], [HouseNumber: %s] [Zip: %s], [City: %s]", temp.Address.Road, temp.Address.HouseNumber, zip, city)
	}
	return address, zip, city, nil
}
