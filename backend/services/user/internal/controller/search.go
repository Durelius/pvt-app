package controller

import (
	"encoding/json"
	"net/http"

	plog "github.com/durelius/go-prodlog"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
	"github.com/durelius/pvt-app/backend/services/user/internal/repository"
)

func SearchUsersHandler(w http.ResponseWriter, r *http.Request) {
	claims := standardrouter.ClaimsFromContext(r.Context())
	if claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	q := r.URL.Query().Get("q")
	if len(q) < 2 {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("[]"))
		return
	}

	db := shareddb.Instance()
	users, err := repository.SearchUsers(db, q, claims.GoogleID)
	if err != nil {
		plog.Errorf("search users: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}
