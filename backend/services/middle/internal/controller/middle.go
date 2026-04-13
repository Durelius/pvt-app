package controller

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/durelius/pvt-app/backend/services/middle/internal/location"
	"github.com/durelius/pvt-app/backend/services/middle/internal/middle"
	"github.com/durelius/pvt-app/backend/services/middle/internal/places"
)

func MiddleEndpoint(w http.ResponseWriter, r *http.Request) {
	rawAddresses := r.URL.Query().Get("addresses")
	rawPoints := r.URL.Query().Get("points")
	if rawAddresses == "" && rawPoints == "" {
		http.Error(w, "You need to provide either addresses or points (coordinates) to the query", http.StatusBadRequest)
		return
	}

	var points []location.Point

	if len(rawAddresses) > 0 {
		var addresses []location.Address
		if err := json.Unmarshal([]byte(rawAddresses), &addresses); err != nil {
			http.Error(w, "invalid addresses format", http.StatusBadRequest)
			return
		}

		for _, address := range addresses {
			point, err := address.Point()
			if err != nil {
				log.Println(err)
				http.Error(w, "Could not convert address to point", http.StatusBadRequest)
				return
			}
			points = append(points, *point)
		}
	} else {
		if err := json.Unmarshal([]byte(rawPoints), &points); err != nil {
			http.Error(w, "invalid points format", http.StatusBadRequest)
			return
		}
	}
	locationType := r.URL.Query().Get("location_type")
	if locationType == "" {
		http.Error(w, "Empty location type (location_type)", http.StatusBadRequest)
		return
	}
	avg, err := middle.Average(points)
	if err != nil {
		log.Println(err)
		http.Error(w, "Couldn't find the average point", http.StatusBadRequest)
		return
	}
	nearby, err := places.Nearby(*avg, locationType)
	if err != nil {
		log.Println(err)
		http.Error(w, "Couldn't find nearby locations of type: "+locationType, http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(nearby)
}
