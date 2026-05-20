package standardrouter

import (
	"context"
	"net/http"
	"os"
	"strings"

	plog "github.com/durelius/go-prodlog"
	jwt "github.com/golang-jwt/jwt/v5"
)

type UserClaims struct {
	UserID   int    `json:"user_id"`
	Email    string `json:"email"`
	GoogleID string `json:"google_id"`
	jwt.RegisteredClaims
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

		claims := &UserClaims{}
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(os.Getenv("JWT_SECRET")), nil
		})
		if err != nil || !token.Valid {
			plog.Infof("auth rejected: %v", err)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), claimsContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
