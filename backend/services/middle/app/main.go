package main

import (
	"github.com/durelius/pvt-app/backend/services/middle/internal/controller"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
)

func main() {

	router, _ := standardrouter.Init()
	// add endpoints here
	router.HandleFunc("/middleplaces", controller.MiddleEndpoint)
	standardrouter.Start(router)
}
