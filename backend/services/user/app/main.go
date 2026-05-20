package main

import (
	"os"

	plog "github.com/durelius/go-prodlog"
	shareddb "github.com/durelius/pvt-app/backend/shared/db"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
	"github.com/durelius/pvt-app/backend/services/user/internal/controller"
)

func main() {
	logDir := "/app/logs"
	if err := os.MkdirAll(logDir, 0755); err == nil {
		plog.SetLogFilePrefix("user")
		plog.EnableLogFile(logDir)
	}

	if _, err := shareddb.Connect(); err != nil {
		plog.Fatalf("db connect failed: %v", err)
	}

	router, _ := standardrouter.Init()
	router.HandleFunc("/login", controller.LoginHandler).Methods("POST")
	standardrouter.Start(router)
}
