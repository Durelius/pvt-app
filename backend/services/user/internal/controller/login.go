package controller

import (
	"encoding/json"
	"net/http"
	"os"
	"time"

	plog "github.com/durelius/go-prodlog"
	jwt "github.com/golang-jwt/jwt/v5"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
	"github.com/durelius/pvt-app/backend/services/user/internal/googleauth"
	"github.com/durelius/pvt-app/backend/services/user/internal/repository"
)

type loginRequest struct {
	IDToken string `json:"id_token"`
}

type loginResponse struct {
	Token string      `json:"token"`
	User  any `json:"user"`
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
	user, err := repository.UpsertUser(db, profile)
	if err != nil {
		plog.Errorf("upsert user failed: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	token, err := signJWT(user.ID, user.Email, user.GoogleID)
	if err != nil {
		plog.Errorf("JWT sign failed: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(loginResponse{Token: token, User: user})
}

func signJWT(userID int, email, googleID string) (string, error) {
	claims := standardrouter.UserClaims{
		UserID:   userID,
		Email:    email,
		GoogleID: googleID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString([]byte(os.Getenv("JWT_SECRET")))
}
