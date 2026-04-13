package middleware

import "net/http"

func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		//verify that user JWT is okay here eventually someitme
		next.ServeHTTP(w, r)
	})
}
