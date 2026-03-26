package main

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
	url, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(url)
	return func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
	}
}

func main() {
	r := mux.NewRouter()

	entries, err := os.ReadDir("/services/")
	if err != nil {
		log.Fatal(err)
	}

	defaultPort := 8080
	for i, e := range entries {
		port := i + 1 + defaultPort
		name := e.Name()
		serviceURL := fmt.Sprintf("http://%s-service:%d", name, port)
		pathPrefix := fmt.Sprintf("/api/%s", name)
		r.PathPrefix(pathPrefix).HandlerFunc(proxyTo(serviceURL))
		log.Printf("running rev proxy to service %s on %s", name, serviceURL)
	}

	log.Println("gateway running on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}
