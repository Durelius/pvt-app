package middle

import (
	"fmt"
	"math"
	"sort"

	"github.com/durelius/pvt-app/backend/services/middle/internal/location"
)

func Average(points []location.Point) (*location.Point, error) {
	n := float64(len(points))
	if n == 0 {
		return nil, fmt.Errorf("Slice provided is empty")
	}
	middle := location.Point{}
	for _, point := range points {
		if point.Latitude == 0 || point.Longitude == 0 {
			return nil, fmt.Errorf("Point has zero value")
		}
		middle.Latitude += point.Latitude
		middle.Longitude += point.Longitude
	}
	middle.Latitude = floatToSixDecimals(middle.Latitude / n)
	middle.Longitude = floatToSixDecimals(middle.Longitude / n)
	return &middle, nil
}
func Median(points []location.Point) (*location.Point, error) {
	n := len(points)
	if n == 0 {
		return nil, fmt.Errorf("Slice provided is empty")
	}

	lats := make([]float64, n)
	lons := make([]float64, n)
	for i, p := range points {
		if p.Latitude == 0 || p.Longitude == 0 {
			return nil, fmt.Errorf("Point has zero value")
		}
		lats[i] = p.Latitude
		lons[i] = p.Longitude
	}
	sort.Float64s(lats)
	sort.Float64s(lons)

	median := location.Point{}
	if n%2 == 0 {
		median.Latitude = (lats[n/2-1] + lats[n/2]) / 2
		median.Longitude = (lons[n/2-1] + lons[n/2]) / 2
	} else {
		median.Latitude = lats[n/2]
		median.Longitude = lons[n/2]
	}

	median.Latitude = floatToSixDecimals(median.Latitude)
	median.Longitude = floatToSixDecimals(median.Longitude)

	return &median, nil
}

func floatToSixDecimals(num float64) float64 {
	return math.Round(num*1e6) / 1e6

}
