package repository

import (
	models "github.com/durelius/pvt-app/backend/shared/models"
	"github.com/jmoiron/sqlx"
)

func GetUserByGoogleID(db *sqlx.DB, googleID string) (*models.User, error) {
	var user models.User
	err := db.QueryRowx(
		`SELECT id, google_id, email, name, picture, email_verified FROM users WHERE google_id = $1`,
		googleID,
	).StructScan(&user)
	return &user, err
}

func SearchUsers(db *sqlx.DB, query, excludeGoogleID string) ([]models.FriendUser, error) {
	var users []models.FriendUser
	err := db.Select(&users, `
		SELECT id, name, picture FROM users
		WHERE google_id != $1
		  AND (name ILIKE '%' || $2 || '%' OR email ILIKE '%' || $2 || '%')
		LIMIT 10
	`, excludeGoogleID, query)
	if users == nil {
		users = []models.FriendUser{}
	}
	return users, err
}

func SendFriendRequest(db *sqlx.DB, senderID, receiverID int) error {
	_, err := db.Exec(`
		INSERT INTO friendships (sender_id, receiver_id, status)
		VALUES ($1, $2, 'pending')
		ON CONFLICT (sender_id, receiver_id) DO NOTHING
	`, senderID, receiverID)
	return err
}

func GetFriends(db *sqlx.DB, userID int) ([]models.FriendUser, error) {
	var friends []models.FriendUser
	err := db.Select(&friends, `
		SELECT u.id, u.name, u.picture FROM users u
		JOIN friendships f ON (
			(f.sender_id = $1 AND f.receiver_id = u.id) OR
			(f.receiver_id = $1 AND f.sender_id = u.id)
		)
		WHERE f.status = 'accepted'
	`, userID)
	if friends == nil {
		friends = []models.FriendUser{}
	}
	return friends, err
}

func GetPendingRequests(db *sqlx.DB, userID int) ([]models.PendingRequest, error) {
	rows, err := db.Queryx(`
		SELECT f.id, u.id as sender_id, u.name as sender_name, u.picture as sender_picture
		FROM friendships f
		JOIN users u ON u.id = f.sender_id
		WHERE f.receiver_id = $1 AND f.status = 'pending'
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []models.PendingRequest
	for rows.Next() {
		var row struct {
			ID            int    `db:"id"`
			SenderID      int    `db:"sender_id"`
			SenderName    string `db:"sender_name"`
			SenderPicture string `db:"sender_picture"`
		}
		if err := rows.StructScan(&row); err != nil {
			return nil, err
		}
		requests = append(requests, models.PendingRequest{
			ID: row.ID,
			Sender: models.FriendUser{
				ID:      row.SenderID,
				Name:    row.SenderName,
				Picture: row.SenderPicture,
			},
		})
	}
	if requests == nil {
		requests = []models.PendingRequest{}
	}
	return requests, nil
}

func RespondToRequest(db *sqlx.DB, friendshipID, receiverID int, status string) error {
	_, err := db.Exec(`
		UPDATE friendships SET status = $1, updated_at = NOW()
		WHERE id = $2 AND receiver_id = $3
	`, status, friendshipID, receiverID)
	return err
}
