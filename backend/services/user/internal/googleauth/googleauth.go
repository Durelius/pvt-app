package googleauth

import (
	"context"

	plog "github.com/durelius/go-prodlog"
	"google.golang.org/api/idtoken"
)

const webClientID = "169231317250-nc8otuvk6ic7cqii3sfdd4pbbp8ge9d7.apps.googleusercontent.com"

type GoogleProfile struct {
	GoogleID      string `json:"google_id"`
	Email         string `json:"email"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	EmailVerified bool   `json:"email_verified"`
}

func VerifyGoogleToken(token string) (*GoogleProfile, error) {
	plog.Info("verifying Google token")

	payload, err := idtoken.Validate(context.Background(), token, webClientID)
	if err != nil {
		return nil, err
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
