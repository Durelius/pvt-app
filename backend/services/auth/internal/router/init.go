package router

import (
	"net/http"

	"github.com/gorilla/mux"
)

func Init(r *mux.Router) {
	api := r.PathPrefix("/api/v1").Subrouter()

	api.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}).Methods("GET")
	// api.HandleFunc("/health", controllers.HealthEndpoint).Methods("get")
}
