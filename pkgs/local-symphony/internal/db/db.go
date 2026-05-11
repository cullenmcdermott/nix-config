package db

import (
	"database/sql"
	"fmt"
	"os"

	_ "modernc.org/sqlite"
)

type Store struct{ db *sql.DB }

func Open(path string) (*Store, error) {
	// WAL keeps readers and writers non-blocking.
	// _foreign_keys enforces FK constraints.
	dsn := path + "?_journal_mode=WAL&_foreign_keys=on"
	d, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w", path, err)
	}
	// Single writer: SQLite serializes writes within a single DB handle
	// via its internal lock mechanism. MaxOpenConns=1 forces all goroutines
	// to funnel through one connection, making CreateIssue's transaction
	// the sole serialization point.
	d.SetMaxOpenConns(1)
	// Tighten file mode — the DataDir is 0750 but the DB file inherits umask.
	_ = os.Chmod(path, 0600)
	s := &Store{db: d}
	if err := s.migrate(); err != nil {
		d.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

// migrations is an ordered list of versioned schema changes. Each migration
// runs exactly once. The schema_version table tracks which migrations have
// been applied. Never edit an applied migration — append a new one instead.
var migrations = []struct {
	version int
	sql     string
}{
	{1, `
		CREATE TABLE IF NOT EXISTS issues (
			id           TEXT PRIMARY KEY,
			identifier   TEXT UNIQUE NOT NULL,
			project_slug TEXT NOT NULL,
			title        TEXT NOT NULL,
			description  TEXT NOT NULL DEFAULT '',
			priority     INTEGER,
			state        TEXT NOT NULL DEFAULT 'idea',
			labels       TEXT NOT NULL DEFAULT '[]',
			blocked_by   TEXT NOT NULL DEFAULT '[]',
			assignee     TEXT,
			created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);

		CREATE TABLE IF NOT EXISTS issue_notes (
			id         TEXT PRIMARY KEY,
			issue_id   TEXT NOT NULL REFERENCES issues(id),
			author     TEXT NOT NULL,
			body       TEXT NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);

		CREATE TABLE IF NOT EXISTS issue_events (
			id         TEXT PRIMARY KEY,
			issue_id   TEXT NOT NULL REFERENCES issues(id),
			actor      TEXT NOT NULL,
			event_type TEXT NOT NULL,
			metadata   TEXT NOT NULL DEFAULT '{}',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);

		CREATE TABLE IF NOT EXISTS projects (
			slug       TEXT PRIMARY KEY,
			name       TEXT NOT NULL DEFAULT '',
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);

		-- Per-project monotonic counter for issue identifiers. CreateIssue
		-- updates this inside the same transaction as the INSERT to make
		-- identifier assignment race-free across concurrent processes.
		CREATE TABLE IF NOT EXISTS project_counters (
			slug TEXT PRIMARY KEY,
			seq  INTEGER NOT NULL DEFAULT 0
		);
	`},
}

func (s *Store) migrate() error {
	if _, err := s.db.Exec(`CREATE TABLE IF NOT EXISTS schema_version(
		version INTEGER PRIMARY KEY,
		applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
	)`); err != nil {
		return err
	}
	var current int
	_ = s.db.QueryRow(`SELECT COALESCE(MAX(version), 0) FROM schema_version`).Scan(&current)
	for _, m := range migrations {
		if m.version <= current {
			continue
		}
		tx, err := s.db.Begin()
		if err != nil {
			return err
		}
		if _, err := tx.Exec(m.sql); err != nil {
			tx.Rollback()
			return fmt.Errorf("migration %d: %w", m.version, err)
		}
		if _, err := tx.Exec(`INSERT INTO schema_version(version) VALUES(?)`, m.version); err != nil {
			tx.Rollback()
			return fmt.Errorf("record migration %d: %w", m.version, err)
		}
		if err := tx.Commit(); err != nil {
			return err
		}
	}
	return nil
}