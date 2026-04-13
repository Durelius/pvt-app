package main

import (
	"log"

	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println(err)
	}

	router, _ := standardrouter.Init()
	// add endpoints here
	standardrouter.Start(router)
}
