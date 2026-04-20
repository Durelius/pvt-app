package main

import (
	"encoding/json"
	"log"
	"net/http"

	controller "github.com/durelius/pvt-app/backend/services/sl/internal/controller"
	"github.com/durelius/pvt-app/backend/services/sl/internal/searchaddress"
	"github.com/durelius/pvt-app/backend/shared/models/location"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
)

func main() {

	router, _ := standardrouter.Init()
	// add endpoints here
	router.HandleFunc("/trip", slEndpoint).Methods("GET")
	standardrouter.Start(router)
	router.HandleFunc("/trips", controller.TripEndpoint)

}

func slEndpoint(w http.ResponseWriter, r *http.Request) {

	rawFrom := r.URL.Query().Get("from")
	rawTo := r.URL.Query().Get("to")
	var from location.Address
	var to location.Address

	if err := json.Unmarshal([]byte(rawFrom), &from); err != nil {
		http.Error(w, "invalid from format", http.StatusBadRequest)
		return
	}
	if err := json.Unmarshal([]byte(rawTo), &to); err != nil {
		http.Error(w, "invalid to format", http.StatusBadRequest)
		return
	}

	res, err := searchaddress.AddressSearch(from, to)
	if err != nil {
		log.Println(err)
		http.Error(w, "failed to search address at SL", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}
