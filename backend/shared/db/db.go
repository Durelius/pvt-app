package db

import (
	"fmt"
	"os"
	"sync"

	plog "github.com/durelius/go-prodlog"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
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
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id             SERIAL PRIMARY KEY,
			google_id      TEXT UNIQUE NOT NULL,
			email          TEXT UNIQUE NOT NULL,
			name           TEXT NOT NULL,
			picture        TEXT,
			email_verified BOOLEAN DEFAULT FALSE,
			created_at     TIMESTAMPTZ DEFAULT NOW(),
			updated_at     TIMESTAMPTZ DEFAULT NOW()
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
