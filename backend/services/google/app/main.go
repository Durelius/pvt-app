package main

import (
	"fmt"
	"net/http"
	"os"

	logger "github.com/durelius/go-prodlog"
	"github.com/gorilla/mux"
)

func main() {
	r := mux.NewRouter()

	serviceName := os.Getenv("SERVICE_NAME")
	sub := r.PathPrefix(fmt.Sprintf("/api/%s", serviceName)).Subrouter()

	sub.HandleFunc("/health", healthHandler).Methods(http.MethodGet)

	sub.HandleFunc("/example", exampleHandler).Methods(http.MethodGet)

	port := ":8080"
	logger.Infof("%s listening on %s", serviceName, port)
	logger.Fatal(http.ListenAndServe(port, r))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func exampleHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message": "hello from example"}`))
}
