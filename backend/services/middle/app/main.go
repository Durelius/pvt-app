package main

import (
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

	router.HandleFunc("/middleplaces", controller.MiddleEndpoint)
	standardrouter.Start(router)
}
