package models

type User struct {
	ID              int     `json:"id"               db:"id"`
	GoogleID        string  `json:"google_id"        db:"google_id"`
	Email           string  `json:"email"            db:"email"`
	Name            string  `json:"name"             db:"name"`
	Picture         string  `json:"picture"          db:"picture"`
	EmailVerified   bool    `json:"email_verified"   db:"email_verified"`
	HomeAddressName string  `json:"home_address_name" db:"home_address_name"`
	HomeAddressLat  float64 `json:"home_address_lat"  db:"home_address_lat"`
	HomeAddressLon  float64 `json:"home_address_lon"  db:"home_address_lon"`
}

type Friendship struct {
	ID         int    `json:"id"          db:"id"`
	SenderID   int    `json:"sender_id"   db:"sender_id"`
	ReceiverID int    `json:"receiver_id" db:"receiver_id"`
	Status     string `json:"status"      db:"status"`
}

type FriendUser struct {
	ID              int     `json:"id"               db:"id"`
	Name            string  `json:"name"             db:"name"`
	Picture         string  `json:"picture"          db:"picture"`
	HomeAddressName string  `json:"home_address_name" db:"home_address_name"`
	HomeAddressLat  float64 `json:"home_address_lat"  db:"home_address_lat"`
	HomeAddressLon  float64 `json:"home_address_lon"  db:"home_address_lon"`
}

type PendingRequest struct {
	ID     int    `json:"id"     db:"id"`
	Sender FriendUser `json:"sender"`
}
