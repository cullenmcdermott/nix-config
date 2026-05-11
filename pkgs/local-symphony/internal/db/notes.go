package db

import "time"

type Note struct {
	ID        string
	IssueID   string
	Author    string
	Body      string
	CreatedAt time.Time
}

type Event struct {
	ID        string
	IssueID   string
	Actor     string
	EventType string
	Metadata  string
	CreatedAt time.Time
}

func (s *Store) AddNote(identifier, author, body string) error {
	issue, err := s.GetIssue(identifier)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(
		`INSERT INTO issue_notes(id,issue_id,author,body) VALUES(?,?,?,?)`,
		newID(), issue.ID, author, body,
	)
	return err
}

func (s *Store) ListNotes(identifier string) ([]*Note, error) {
	issue, err := s.GetIssue(identifier)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(
		`SELECT id,issue_id,author,body,created_at FROM issue_notes
		 WHERE issue_id=? ORDER BY created_at ASC`, issue.ID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*Note
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.IssueID, &n.Author, &n.Body, &n.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, &n)
	}
	return out, rows.Err()
}

func (s *Store) ListEvents(identifier string) ([]*Event, error) {
	issue, err := s.GetIssue(identifier)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(
		`SELECT id,issue_id,actor,event_type,metadata,created_at FROM issue_events
		 WHERE issue_id=? ORDER BY created_at ASC`, issue.ID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*Event
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.IssueID, &e.Actor, &e.EventType, &e.Metadata, &e.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, &e)
	}
	return out, rows.Err()
}