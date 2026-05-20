package repository

import (
	"github.com/durelius/pvt-app/backend/services/user/internal/googleauth"
	models "github.com/durelius/pvt-app/backend/shared/models"
	"github.com/jmoiron/sqlx"
)

func UpsertUser(db *sqlx.DB, profile *googleauth.GoogleProfile) (*models.User, error) {
	var user models.User
	err := db.QueryRowx(`
		INSERT INTO users (google_id, email, name, picture, email_verified)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (google_id) DO UPDATE SET
			name           = EXCLUDED.name,
			picture        = EXCLUDED.picture,
			email_verified = EXCLUDED.email_verified,
			updated_at     = NOW()
		RETURNING id, google_id, email, name, picture, email_verified
	`, profile.GoogleID, profile.Email, profile.Name, profile.Picture, profile.EmailVerified).StructScan(&user)
	return &user, err
}
