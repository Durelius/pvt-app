package googleauth

import (
	"context"
	"fmt"

	plog "github.com/durelius/go-prodlog"
	"google.golang.org/api/idtoken"
)

// All valid OAuth client IDs for this app (web, iOS, Android).
var validClientIDs = []string{
	"648166383994-cjdcvd4s66l8uuf84nn7gs2lqh1r1jva.apps.googleusercontent.com",
	"169231317250-nc8otuvk6ic7cqii3sfdd4pbbp8ge9d7.apps.googleusercontent.com",
	"648166383994-2s5edahe0h27fqrjp822un6ki6cneun4.apps.googleusercontent.com",
	"648166383994-60injkuta3jv8thamge46fevoq4kjd3v.apps.googleusercontent.com",
	"648166383994-8l68bnq765b15egumi92q9o0q7hagq4q.apps.googleusercontent.com",
	"648166383994-cjdcvd4s66l8uuf84nn7gs2lqh1r1jva.apps.googleusercontent.com",
	"648166383994-7t78qd26534cv56uj61ep2j6ffll0ob8.apps.googleusercontent.com",
}

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
	validAud := false
	for _, id := range validClientIDs {
		if payload.Audience == id {
			validAud = true
			break
		}
	}
	if !validAud {
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
