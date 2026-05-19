package controller

import (
	"encoding/json"
	"net/http"

	verifyer "github.com/durelius/pvt-app/backend/services/signinverification/internal/verifyer"
	// Import your core verification package path here
	//"github.com/durelius/pvt-app/backend/services/googlesigninverification/internal/verifygooglesignin"
)

type TokenRequest struct {
	IDToken string `json:"id_token"`
}

func VerifyGoogleSignInEndpoint(w http.ResponseWriter, r *http.Request) {
	//Check if contains id_token
	var req TokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IDToken == "" {
		http.Error(w, "Invalid request payload or missing token", http.StatusBadRequest)
		return
	}

	//Verify the token and get the user profile
	profile, err := verifyer.VerifyGoogleToken(req.IDToken)
	if profile == nil {
		http.Error(w, "Unauthorized: Invalid token", http.StatusUnauthorized)
		return
	}
	if err != nil {
		http.Error(w, "Error verifying token: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(profile)
}
