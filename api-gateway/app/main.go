package main

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	logger "github.com/durelius/go-prodlog"
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

	entries, err := os.ReadDir("../services/")
	if err != nil {
		logger.Fatal(err)
	}

	defaultPort := 8080
	for i, e := range entries {
		port := i + 1 + defaultPort
		name := e.Name()
		pathPrefix := fmt.Sprintf("/api/%s", name)
		serviceURL := fmt.Sprintf("http://%s-service:%d", name, port)
		r.PathPrefix(pathPrefix).HandlerFunc(proxyTo(serviceURL))
		logger.Infof("running rev proxy to service %s on %s", name, serviceURL)
	}

	logger.Info("gateway running on :8080")
	logger.Fatal(http.ListenAndServe(":8080", r))
}
