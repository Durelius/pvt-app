package main

//Nils Test
// Kim Test!!!!
//Erik Text

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	plog "github.com/durelius/go-prodlog"
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
	logDir := "/app/logs"
	if err := os.MkdirAll(logDir, 0755); err == nil {
		plog.SetLogFilePrefix("api-gateway")
		plog.EnableLogFile(logDir)
	}

	r := mux.NewRouter()

	entries, err := os.ReadDir("../services/")
	if err != nil {
		plog.Fatal(err)
	}
	api := r.PathPrefix("/api").Subrouter()

	for _, e := range entries {
		name := e.Name()
		pathPrefix := fmt.Sprintf("/api/%s", name)
		serviceURL := fmt.Sprintf("http://%s:8080", name)
		r.PathPrefix(pathPrefix).HandlerFunc(proxyTo(serviceURL))
		plog.Infof("running rev proxy to service %s on %s", name, serviceURL)
	}

	api.HandleFunc("/health", healthHandler).Methods(http.MethodGet)

	plog.Info("gateway running on :8080")
	plog.Fatal(http.ListenAndServe(":8080", r))

}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}
