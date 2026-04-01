package router

import (
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

func Init(r *mux.Router) {
	api := r.PathPrefix("/api/v1").Subrouter()

	api.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)   // sets HTTP status 200
		w.Write([]byte("OK"))          // writes "OK" to the response body
		log.Println("Health check OK") // optional logging
	}).Methods("GET")
	// api.HandleFunc("/health", controllers.HealthEndpoint).Methods("get")
}
