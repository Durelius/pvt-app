package verifyer

import (
	"testing"

	"github.com/durelius/pvt-app/backend/services/signinverification/internal/verifyer"
)

func TestVerifyGoogleToken(t *testing.T) {
	// This test is a placeholder. In a real test, you would use a valid Google token.
	// For security reasons, do not hardcode real tokens in your tests.
	fakeToken := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

	profile, err := verifyer.VerifyGoogleToken(fakeToken)
	if err == nil {
		t.Fatal("Expected an error because the token is invalid, but got nil")
	}

	if profile != nil {
		t.Errorf("Expected profile to be nil on failure, but got: %+v", profile)
	}

	t.Logf("Successfully caught expected error: %v", err)
}
