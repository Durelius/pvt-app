package main

import (
	"net/http"
	"os"

	plog "github.com/durelius/go-prodlog"
	"github.com/durelius/pvt-app/backend/services/middle/internal/controller"
	"github.com/durelius/pvt-app/backend/services/middle/internal/graph"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
)

func main() {
	logDir := "/app/logs"
	if err := os.MkdirAll(logDir, 0755); err == nil {
		plog.SetLogFilePrefix("middle")
		plog.EnableLogFile(logDir)
	}

	if _, err := graph.NewWithData(); err != nil {
		plog.Fatalf("failed to load SL graph: %v", err)
	}

	router, _ := standardrouter.Init()

	//flutter körs på http://localhost:52770/, men behöver använda localhost:8080
	router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	})

	router.HandleFunc("/middleplaces", controller.MiddleEndpoint)
	standardrouter.Start(router)
}
