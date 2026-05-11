package main

import (
	"encoding/json"
	"net/http"
	"os"

	plog "github.com/durelius/go-prodlog"
	controller "github.com/durelius/pvt-app/backend/services/sl/internal/controller"
	"github.com/durelius/pvt-app/backend/services/sl/internal/searchaddress"
	"github.com/durelius/pvt-app/backend/shared/models/location"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
)

func main() {
	logDir := "/app/logs"
	if err := os.MkdirAll(logDir, 0755); err == nil {
		plog.SetLogFilePrefix("sl")
		plog.EnableLogFile(logDir)
	}

	router, _ := standardrouter.Init()
	// add endpoints here
	router.HandleFunc("/trip", slEndpoint).Methods("GET")
	router.HandleFunc("/trips", controller.TripEndpoint)
	standardrouter.Start(router)

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
		plog.Error(err)
		http.Error(w, "failed to search address at SL", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}
