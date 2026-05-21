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

	router, authRouter := standardrouter.Init()
	router.HandleFunc("/login", controller.LoginHandler).Methods("POST")

	authRouter.HandleFunc("/search", controller.SearchUsersHandler).Methods("GET")
	authRouter.HandleFunc("/friends/request", controller.SendRequestHandler).Methods("POST")
	authRouter.HandleFunc("/friends", controller.GetFriendsHandler).Methods("GET")
	authRouter.HandleFunc("/friends/pending", controller.GetPendingHandler).Methods("GET")
	authRouter.HandleFunc("/friends/{id}/accept", controller.AcceptHandler).Methods("PUT")
	authRouter.HandleFunc("/friends/{id}/decline", controller.DeclineHandler).Methods("PUT")
	authRouter.HandleFunc("/home-address", controller.SetHomeAddressHandler).Methods("PUT")

	standardrouter.Start(router)
}
