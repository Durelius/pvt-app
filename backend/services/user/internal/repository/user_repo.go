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
		RETURNING id, google_id, email, name, picture, email_verified,
		          COALESCE(home_address_name, '') AS home_address_name,
		          COALESCE(home_address_lat, 0)  AS home_address_lat,
		          COALESCE(home_address_lon, 0)  AS home_address_lon
	`, profile.GoogleID, profile.Email, profile.Name, profile.Picture, profile.EmailVerified).StructScan(&user)
	return &user, err
}

func UpdateHomeAddress(db *sqlx.DB, userID int, name string, lat, lon float64) error {
	_, err := db.Exec(`
		UPDATE users SET home_address_name=$1, home_address_lat=$2, home_address_lon=$3, updated_at=NOW()
		WHERE id=$4
	`, name, lat, lon, userID)
	return err
}
