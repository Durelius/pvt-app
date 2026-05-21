package controller

import (
	"encoding/json"
	"net/http"

	plog "github.com/durelius/go-prodlog"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	"github.com/durelius/pvt-app/backend/services/user/internal/repository"
)

func SetHomeAddressHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var body struct {
		Name string  `json:"name"`
		Lat  float64 `json:"lat"`
		Lon  float64 `json:"lon"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Name == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	db := shareddb.Instance()
	if err := repository.UpdateHomeAddress(db, userID, body.Name, body.Lat, body.Lon); err != nil {
		plog.Errorf("update home address: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
