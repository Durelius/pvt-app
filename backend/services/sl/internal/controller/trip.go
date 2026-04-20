package controller

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/durelius/pvt-app/backend/services/sl/internal/searchaddress"
	"github.com/durelius/pvt-app/backend/shared/models/location"
)

func TripEndpoint(w http.ResponseWriter, r *http.Request) {
	rawFrom := r.URL.Query().Get("from")
	rawTo := r.URL.Query().Get("to")

	if rawFrom == "" || rawTo == "" {
		http.Error(w, "You need to provide both 'from' and 'to' addresses", http.StatusBadRequest)
		return
	}

	//parsa from
	var from location.Address
	if err := json.Unmarshal([]byte(rawFrom), &from); err != nil {
		http.Error(w, "invalid 'from' address format", http.StatusBadRequest)
		return
	}

	//parsa to
	var to location.Address
	if err := json.Unmarshal([]byte(rawTo), &to); err != nil {
		http.Error(w, "invalid 'to' address format", http.StatusBadRequest)
		return
	}

	// parsa arrivaltime
	rawArrivalTime := r.URL.Query().Get("arrivalTime")
	if rawArrivalTime == "" {
		http.Error(w, "You need to provide 'arrivalTime'", http.StatusBadRequest)
		return
	}

	//anropa addressSearch för att få resedata i trips
	trips, err := searchaddress.AddressSearch(from, to)
	if err != nil {
		log.Println(err)
		http.Error(w, "Couldn't fetch trips from SL", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(trips)
}
