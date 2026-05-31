package googleauth

import (
	"context"
	"fmt"
	"slices"

	plog "github.com/durelius/go-prodlog"
	standardrouter "github.com/durelius/pvt-app/backend/shared/router"
	"google.golang.org/api/idtoken"
)

type GoogleProfile struct {
	GoogleID      string `json:"google_id"`
	Email         string `json:"email"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	EmailVerified bool   `json:"email_verified"`
}

func VerifyGoogleToken(token string) (*GoogleProfile, error) {
	plog.Info("verifying Google token")

	// Validate signature + expiry without audience restriction, then check aud manually.
	payload, err := idtoken.Validate(context.Background(), token, "")
	if err != nil {
		return nil, err
	}
	if !slices.Contains(standardrouter.ValidClientIDs, payload.Audience) {
		return nil, fmt.Errorf("token audience %q is not a recognised client ID", payload.Audience)
	}

	profile := &GoogleProfile{
		GoogleID: payload.Subject,
		Email:    payload.Claims["email"].(string),
		Name:     payload.Claims["name"].(string),
		Picture:  payload.Claims["picture"].(string),
	}
	if verified, ok := payload.Claims["email_verified"].(bool); ok {
		profile.EmailVerified = verified
	}

	return profile, nil
}
