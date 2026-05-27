package repository

import "github.com/jmoiron/sqlx"

type Notification struct {
	ID      int    `db:"id"      json:"id"`
	Message string `db:"message" json:"message"`
	Read    bool   `db:"read"    json:"read"`
}

func InsertNotification(db *sqlx.DB, userID int, message string) error {
	_, err := db.Exec(
		`INSERT INTO notifications (user_id, message) VALUES ($1, $2)`,
		userID, message,
	)
	return err
}

func GetUnreadNotifications(db *sqlx.DB, userID int) ([]Notification, error) {
	var rows []Notification
	err := db.Select(&rows,
		`SELECT id, message, read FROM notifications WHERE user_id = $1 AND read = FALSE ORDER BY created_at`,
		userID,
	)
	if rows == nil {
		rows = []Notification{}
	}
	return rows, err
}

func MarkNotificationsRead(db *sqlx.DB, userID int) error {
	_, err := db.Exec(
		`UPDATE notifications SET read = TRUE WHERE user_id = $1 AND read = FALSE`,
		userID,
	)
	return err
}
