package main

//Nils Test
// Kim Test!!!!
//Erik Text

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	"github.com/gorilla/mux"
)

func proxyTo(target string) http.HandlerFunc {
	URL, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(URL)
	return func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
	}
}

func main() {
	r := mux.NewRouter()

	entries, err := os.ReadDir("../services/")
	if err != nil {
		log.Fatal(err)
	}
	api := r.PathPrefix("/api").Subrouter()

	for _, e := range entries {
		name := e.Name()
		pathPrefix := fmt.Sprintf("/api/%s", name)
		serviceURL := fmt.Sprintf("http://%s:8080", name)
		r.PathPrefix(pathPrefix).HandlerFunc(proxyTo(serviceURL))
		log.Printf("running rev proxy to service %s on %s", name, serviceURL)
	}

	api.HandleFunc("/health", healthHandler).Methods(http.MethodGet)

	log.Print("gateway running on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))

}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}
