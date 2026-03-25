package main

import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"

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

	// Example of API gateway routing to microservices via reverse proxy.
	//we should probably control these via env vars
	r.PathPrefix("/api/users").HandlerFunc(proxyTo("http://user-service:8081"))
	r.PathPrefix("/api/orders").HandlerFunc(proxyTo("http://order-service:8082"))
	r.PathPrefix("/api/products").HandlerFunc(proxyTo("http://product-service:8083"))

	log.Println("gateway running on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}
