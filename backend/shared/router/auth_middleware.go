package standardrouter

import (
	"context"
	"net/http"
	"strings"

	plog "github.com/durelius/go-prodlog"
	"google.golang.org/api/idtoken"
)

var validClientIDs = []string{
	"648166383994-cjdcvd4s66l8uuf84nn7gs2lqh1r1jva.apps.googleusercontent.com",
	"169231317250-nc8otuvk6ic7cqii3sfdd4pbbp8ge9d7.apps.googleusercontent.com",
}

type UserClaims struct {
	GoogleID string
	Email    string
	Name     string
}

type contextKey string

const claimsContextKey contextKey = "user_claims"

func ClaimsFromContext(ctx context.Context) *UserClaims {
	claims, _ := ctx.Value(claimsContextKey).(*UserClaims)
	return claims
}

func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")

		payload, err := idtoken.Validate(r.Context(), tokenStr, "")
		if err != nil {
			plog.Infof("auth rejected: %v", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		validAud := false
		for _, id := range validClientIDs {
			if payload.Audience == id {
				validAud = true
				break
			}
		}
		if !validAud {
			plog.Infof("auth rejected: unrecognised audience %q", payload.Audience)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		claims := &UserClaims{
			GoogleID: payload.Subject,
			Email:    payload.Claims["email"].(string),
		}
		if name, ok := payload.Claims["name"].(string); ok {
			claims.Name = name
		}

		ctx := context.WithValue(r.Context(), claimsContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
