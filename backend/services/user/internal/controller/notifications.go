package controller

import (
	"encoding/json"
	"net/http"

	plog "github.com/durelius/go-prodlog"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	"github.com/durelius/pvt-app/backend/services/user/internal/repository"
)

func GetNotificationsHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	db := shareddb.Instance()
	notifs, err := repository.GetUnreadNotifications(db, userID)
	if err != nil {
		plog.Errorf("get notifications: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(notifs)
}

func MarkNotificationsReadHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	db := shareddb.Instance()
	if err := repository.MarkNotificationsRead(db, userID); err != nil {
		plog.Errorf("mark notifications read: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
