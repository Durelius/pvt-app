package controller

import (
	"encoding/json"
	"net/http"
	"strconv"

	plog "github.com/durelius/go-prodlog"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
	"github.com/durelius/pvt-app/backend/services/user/internal/repository"
	"github.com/gorilla/mux"
)

func callerID(r *http.Request) (int, bool) {
	claims := standardrouter.ClaimsFromContext(r.Context())
	if claims == nil {
		return 0, false
	}
	db := shareddb.Instance()
	user, err := repository.GetUserByGoogleID(db, claims.GoogleID)
	if err != nil {
		return 0, false
	}
	return user.ID, true
}

func SendRequestHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var body struct {
		ReceiverID int `json:"receiver_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.ReceiverID == 0 {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	if body.ReceiverID == userID {
		http.Error(w, "cannot add yourself", http.StatusBadRequest)
		return
	}

	db := shareddb.Instance()
	if err := repository.SendFriendRequest(db, userID, body.ReceiverID); err != nil {
		plog.Errorf("send friend request: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func GetFriendsHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	db := shareddb.Instance()
	friends, err := repository.GetFriends(db, userID)
	if err != nil {
		plog.Errorf("get friends: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(friends)
}

func GetPendingHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	db := shareddb.Instance()
	pending, err := repository.GetPendingRequests(db, userID)
	if err != nil {
		plog.Errorf("get pending requests: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pending)
}

func respondToRequest(w http.ResponseWriter, r *http.Request, status string) {
	userID, ok := callerID(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	idStr := mux.Vars(r)["id"]
	friendshipID, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}

	db := shareddb.Instance()
	if err := repository.RespondToRequest(db, friendshipID, userID, status); err != nil {
		plog.Errorf("respond to request: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func AcceptHandler(w http.ResponseWriter, r *http.Request) {
	respondToRequest(w, r, "accepted")
}

func DeclineHandler(w http.ResponseWriter, r *http.Request) {
	respondToRequest(w, r, "declined")
}
