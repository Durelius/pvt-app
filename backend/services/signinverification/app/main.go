package main

import (
	"os"

	plog "github.com/durelius/go-prodlog"
	controller "github.com/durelius/pvt-app/backend/services/signinverification/internal/controller"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
)

func main() {
	logDir := "/app/logs"
	if err := os.MkdirAll(logDir, 0755); err == nil {
		plog.SetLogFilePrefix("signinverification")
		plog.EnableLogFile(logDir)
	}

	router, _ := standardrouter.Init()
	// add endpoints here
	//router.HandleFunc("/trip", slEndpoint).Methods("GET")
	router.HandleFunc("/verify-google-signin", controller.VerifyGoogleSignInEndpoint).Methods("POST")
	standardrouter.Start(router)

}
