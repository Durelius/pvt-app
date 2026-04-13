package standardrouter

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"golang.org/x/time/rate"
)

// init, add your endpoints, then start
func Init() (router, authRouter *mux.Router) {

	r := mux.NewRouter()
	serviceName := os.Getenv("SERVICE_NAME")
	api := r.PathPrefix(fmt.Sprintf("/api/%s/v1", serviceName)).Subrouter()
	rl := NewIPRateLimiter(rate.Every(time.Second), 10)
	r.Use(rl.Middleware)

	api.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)   // sets HTTP status 200
		w.Write([]byte("OK"))          // writes "OK" to the response body
		log.Println("Health check OK") // optional logging
	}).Methods("GET")

	//auth router is for paths that do require authentication
	auth := api.PathPrefix("/auth").Subrouter()
	auth.Use(AuthMiddleware)

	port := ":8080"
	log.Printf("%s initialized on %s", serviceName, port)
	// log.Fatal(http.ListenAndServe(port, r))
	return api, auth

}

func Start(r *mux.Router) {

	serviceName := os.Getenv("SERVICE_NAME")
	port := ":8080"
	log.Printf("%s starting on %s", serviceName, port)
	log.Fatal(http.ListenAndServe(port, r))
}
