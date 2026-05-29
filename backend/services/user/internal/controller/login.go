package controller

import (
	"encoding/json"
	"net/http"

	plog "github.com/durelius/go-prodlog"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	"github.com/durelius/pvt-app/backend/services/user/internal/googleauth"
	"github.com/durelius/pvt-app/backend/services/user/internal/repository"
	models "github.com/durelius/pvt-app/backend/shared/models"
)

type loginRequest struct {
	IDToken string `json:"id_token"`
}

func LoginHandler(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IDToken == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	profile, err := googleauth.VerifyGoogleToken(req.IDToken)
	if err != nil {
		plog.Infof("google token verification failed: %v", err)
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	db := shareddb.Instance()
	var user *models.User
	if err = shareddb.Retry(3, func() error {
		var e error
		user, e = repository.UpsertUser(db, profile)
		return e
	}); err != nil {
		plog.Errorf("upsert user failed: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}
