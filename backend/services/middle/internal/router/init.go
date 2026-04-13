package router

import (
	"log"
	"net/http"
	"time"

	"github.com/durelius/pvt-app/backend/services/middle/internal/middleware"
	"github.com/gorilla/mux"
	"golang.org/x/time/rate"
)

func Init(r *mux.Router) {
	api := r.PathPrefix("/api/v1").Subrouter()
	rl := middleware.NewIPRateLimiter(rate.Every(time.Second), 10)
	r.Use(rl.Middleware)

	api.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)   // sets HTTP status 200
		w.Write([]byte("OK"))          // writes "OK" to the response body
		log.Println("Health check OK") // optional logging
	}).Methods("GET")

	//auth router is for paths that do require authentication
	auth := api.PathPrefix("/auth").Subrouter()
	auth.Use(middleware.AuthMiddleware)

	// api.HandleFunc("/health", controllers.HealthEndpoint).Methods("get")
}
