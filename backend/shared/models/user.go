package models

type User struct {
	ID            int    `json:"id"             db:"id"`
	GoogleID      string `json:"google_id"      db:"google_id"`
	Email         string `json:"email"          db:"email"`
	Name          string `json:"name"           db:"name"`
	Picture       string `json:"picture"        db:"picture"`
	EmailVerified bool   `json:"email_verified" db:"email_verified"`
}
