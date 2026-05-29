package db

import (
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	plog "github.com/durelius/go-prodlog"
	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

var (
	instance *sqlx.DB
	once     sync.Once
)

func Connect() (*sqlx.DB, error) {
	var initErr error
	once.Do(func() {
		db, err := sqlx.Connect("postgres", dsn())
		if err != nil {
			initErr = err
			return
		}
		if err := migrate(db); err != nil {
			initErr = err
			return
		}
		instance = db
		plog.Info("connected to postgres")
	})
	if initErr != nil {
		return nil, initErr
	}
	return instance, nil
}

func Instance() *sqlx.DB {
	if instance == nil {
		plog.Fatal("db is nil, call Connect first")
	}
	return instance
}

func migrate(db *sqlx.DB) error {
	if _, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id             SERIAL PRIMARY KEY,
			google_id      TEXT UNIQUE NOT NULL,
			email          TEXT UNIQUE NOT NULL,
			name           TEXT NOT NULL,
			picture        TEXT,
			email_verified BOOLEAN DEFAULT FALSE,
			created_at     TIMESTAMPTZ DEFAULT NOW(),
			updated_at     TIMESTAMPTZ DEFAULT NOW()
		);
		CREATE TABLE IF NOT EXISTS friendships (
			id          SERIAL PRIMARY KEY,
			sender_id   INTEGER NOT NULL REFERENCES users(id),
			receiver_id INTEGER NOT NULL REFERENCES users(id),
			status      TEXT NOT NULL DEFAULT 'pending',
			created_at  TIMESTAMPTZ DEFAULT NOW(),
			updated_at  TIMESTAMPTZ DEFAULT NOW(),
			UNIQUE(sender_id, receiver_id)
		)
	`); err != nil {
		return err
	}
	if _, err := db.Exec(`
		ALTER TABLE users
			ADD COLUMN IF NOT EXISTS home_address_name TEXT,
			ADD COLUMN IF NOT EXISTS home_address_lat  FLOAT8,
			ADD COLUMN IF NOT EXISTS home_address_lon  FLOAT8
	`); err != nil {
		return err
	}
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS notifications (
			id         SERIAL PRIMARY KEY,
			user_id    INTEGER NOT NULL REFERENCES users(id),
			message    TEXT NOT NULL,
			read       BOOLEAN NOT NULL DEFAULT FALSE,
			created_at TIMESTAMPTZ DEFAULT NOW()
		)
	`)
	return err
}

func dsn() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		env("DB_HOST", "db"),
		env("DB_PORT", "5432"),
		env("DB_USER", "user"),
		env("DB_PASSWORD", "password"),
		env("DB_NAME", "mydb"),
	)
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// Retry runs fn up to attempts times, backing off 500ms between tries, but
// only retries on transient Postgres errors (e.g. 57P03 "system starting up")
// that occur when the db container restarts during a rolling deploy.
func Retry(attempts int, fn func() error) error {
	var err error
	for i := range attempts {
		err = fn()
		if err == nil || !isTransient(err) {
			return err
		}
		if i < attempts-1 {
			time.Sleep(time.Duration(i+1) * 500 * time.Millisecond)
		}
	}
	return err
}

func isTransient(err error) bool {
	if pqErr, ok := err.(*pq.Error); ok {
		switch pqErr.Code {
		case "57P03", // cannot_connect_now (db starting up)
			"57P01",  // admin_shutdown
			"57P02",  // crash_shutdown
			"08006",  // connection_failure
			"08001",  // sqlclient_unable_to_establish_sqlconnection
			"08004":  // sqlserver_rejected_establishment_of_sqlconnection
			return true
		}
	}
	s := err.Error()
	return strings.Contains(s, "connection refused") || strings.Contains(s, "broken pipe")
}
