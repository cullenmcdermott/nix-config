package db

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

// ErrNoOpTransition signals that a state change requested the issue's current
// state. Callers should treat this as success-with-no-effect, not as a real error.
var ErrNoOpTransition = errors.New("issue is already in that state")

// updatableColumns is the allowlist used by UpdateIssue. It exists to prevent
// SQL-identifier injection via user-supplied map keys; any column not listed
// here is silently dropped.
var updatableColumns = map[string]bool{
	"title":       true,
	"description": true,
	"priority":    true,
	"assignee":    true,
}

type State string

const (
	StateIdea        State = "idea"
	StateBacklog     State = "backlog"
	StateInProgress  State = "in_progress"
	StatePaused      State = "paused"       // agent stopped mid-task; can resume
	StateHumanReview State = "human_review" // agent done, needs human approval
	StateDone        State = "done"         // human-only terminal
	StateCancelled   State = "cancelled"    // human-only terminal
)

// validTransitions lists states that can be reached from each state. Both agents
// and humans may use these, subject to agentForbidden below.
//
// `idea` is reachable from `backlog` and `human_review` so an issue can be
// demoted back to "thinking about it" without being cancelled. No state can
// move out of `done` (terminal — re-open by reading and creating a new issue).
// `cancelled` can only go back to `backlog` and only by a human.
var validTransitions = map[State]map[State]bool{
	StateIdea:        {StateBacklog: true, StateCancelled: true},
	StateBacklog:     {StateInProgress: true, StateIdea: true, StateCancelled: true},
	StateInProgress:  {StateHumanReview: true, StatePaused: true, StateBacklog: true, StateCancelled: true},
	StatePaused:      {StateInProgress: true, StateBacklog: true, StateCancelled: true},
	StateHumanReview: {StateDone: true, StateInProgress: true, StateBacklog: true, StateIdea: true, StateCancelled: true},
	StateDone:        {}, // terminal — no transitions out
	StateCancelled:   {StateBacklog: true}, // only humans can reopen
}

// agentForbidden are states that only humans may transition TO.
var agentForbidden = map[State]bool{
	StateDone:      true,
	StateCancelled: true,
}

type Issue struct {
	ID          string
	Identifier  string
	ProjectSlug string
	Title       string
	Description string
	Priority    *int
	State       State
	Labels      []string
	BlockedBy   []string
	Assignee    string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type ListIssuesOpts struct {
	ProjectSlug string
	State       string
	Limit       int
}

// CreateIssue assigns a project-scoped identifier and inserts the issue.
// All steps (project upsert, counter increment, insert, event log) run inside
// a single IMMEDIATE transaction so two concurrent callers cannot allocate the
// same identifier. The _txlock=immediate DSN setting (see db.go) makes Begin
// acquire a write lock immediately rather than upgrading on first write, which
// is what prevents the SQLITE_BUSY-then-retry race.
func (s *Store) CreateIssue(issue *Issue) error {
	issue.ID = newID()
	if issue.State == "" {
		issue.State = StateIdea
	}

	labelsJSON, err := marshalStringArray(issue.Labels)
	if err != nil {
		return fmt.Errorf("marshal labels: %w", err)
	}
	blockedByJSON, err := marshalStringArray(issue.BlockedBy)
	if err != nil {
		return fmt.Errorf("marshal blocked_by: %w", err)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.Exec(
		`INSERT OR IGNORE INTO projects(slug,name) VALUES(?,?)`,
		issue.ProjectSlug, issue.ProjectSlug,
	); err != nil {
		return fmt.Errorf("upsert project: %w", err)
	}

	// Atomic counter bump per project. INSERT-or-UPDATE in one statement so
	// two callers cannot read the same seq.
	if _, err := tx.Exec(
		`INSERT INTO project_counters(slug,seq) VALUES(?,1)
		 ON CONFLICT(slug) DO UPDATE SET seq = seq + 1`,
		issue.ProjectSlug,
	); err != nil {
		return fmt.Errorf("bump counter: %w", err)
	}
	var seq int
	if err := tx.QueryRow(`SELECT seq FROM project_counters WHERE slug=?`, issue.ProjectSlug).Scan(&seq); err != nil {
		return fmt.Errorf("read counter: %w", err)
	}

	slug := strings.ToUpper(issue.ProjectSlug)
	if len(slug) > 4 {
		slug = slug[:4]
	}
	issue.Identifier = fmt.Sprintf("%s-%03d", slug, seq)

	if _, err := tx.Exec(
		`INSERT INTO issues(id,identifier,project_slug,title,description,priority,state,labels,blocked_by)
		 VALUES(?,?,?,?,?,?,?,?,?)`,
		issue.ID, issue.Identifier, issue.ProjectSlug,
		issue.Title, issue.Description,
		sqlNullInt(issue.Priority),
		string(issue.State),
		labelsJSON,
		blockedByJSON,
	); err != nil {
		return fmt.Errorf("insert issue: %w", err)
	}

	if _, err := tx.Exec(
		`INSERT INTO issue_events(id,issue_id,actor,event_type,metadata) VALUES(?,?,?,?,?)`,
		newID(), issue.ID, "system", "created", `{}`,
	); err != nil {
		return fmt.Errorf("log create event: %w", err)
	}

	return tx.Commit()
}

func (s *Store) GetIssue(identifier string) (*Issue, error) {
	row := s.db.QueryRow(`
		SELECT id,identifier,project_slug,title,description,priority,state,
		       labels,blocked_by,COALESCE(assignee,''),created_at,updated_at
		FROM issues WHERE identifier=?`, identifier)
	return scanIssue(row)
}

func (s *Store) ListIssues(opts ListIssuesOpts) ([]*Issue, error) {
	q := `SELECT id,identifier,project_slug,title,description,priority,state,
		         labels,blocked_by,COALESCE(assignee,''),created_at,updated_at
		  FROM issues WHERE 1=1`
	var args []any
	if opts.ProjectSlug != "" {
		q += " AND project_slug=?"
		args = append(args, opts.ProjectSlug)
	}
	if opts.State != "" {
		q += " AND state=?"
		args = append(args, opts.State)
	}
	q += " ORDER BY priority ASC NULLS LAST, created_at ASC"
	if opts.Limit > 0 {
		q += fmt.Sprintf(" LIMIT %d", opts.Limit)
	}
	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*Issue
	for rows.Next() {
		i, err := scanIssue(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, i)
	}
	return out, rows.Err()
}

// UpdateIssueState transitions state. actor must be "human" for human-only states.
// A no-op transition (to == current state) returns ErrNoOpTransition so callers
// can distinguish "already there" from "illegal" and print a friendly message.
func (s *Store) UpdateIssueState(identifier string, to State, actor string) error {
	issue, err := s.GetIssue(identifier)
	if err != nil {
		return fmt.Errorf("issue %q not found: %w", identifier, err)
	}
	if issue.State == to {
		return ErrNoOpTransition
	}
	if !validTransitions[issue.State][to] {
		return fmt.Errorf("transition %s→%s is not valid", issue.State, to)
	}
	if actor != "human" && agentForbidden[to] {
		return fmt.Errorf("only humans may transition to %q", to)
	}
	_, err = s.db.Exec(
		`UPDATE issues SET state=?, updated_at=CURRENT_TIMESTAMP WHERE identifier=?`,
		string(to), identifier,
	)
	if err != nil {
		return err
	}
	meta := fmt.Sprintf(`{"from":%q,"to":%q}`, issue.State, to)
	_ = s.logEvent(issue.ID, actor, "state_change", meta)
	return nil
}

// UpdateIssue updates a subset of fields on the issue. Only column names in
// updatableColumns are honored — any other key is silently ignored. This is
// the security boundary that prevents callers from injecting arbitrary SQL
// identifiers via the map key (the value side is parameterized).
func (s *Store) UpdateIssue(identifier string, fields map[string]any) error {
	if len(fields) == 0 {
		return nil
	}
	var clauses []string
	var args []any
	for k, v := range fields {
		if !updatableColumns[k] {
			continue
		}
		clauses = append(clauses, k+"=?")
		args = append(args, v)
	}
	if len(clauses) == 0 {
		return nil
	}
	args = append(args, identifier)
	_, err := s.db.Exec(
		`UPDATE issues SET `+strings.Join(clauses, ",")+`,updated_at=CURRENT_TIMESTAMP WHERE identifier=?`,
		args...,
	)
	return err
}

// UpdateIssueAndAddNote applies a state transition AND a note in one transaction.
// Used by `symphony handoff` so the note is never orphaned if the state change
// fails (and vice versa).
func (s *Store) UpdateIssueAndAddNote(identifier string, to State, actor, note string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var issueID, currentState string
	if err := tx.QueryRow(
		`SELECT id, state FROM issues WHERE identifier=?`, identifier,
	).Scan(&issueID, &currentState); err != nil {
		return fmt.Errorf("issue %q not found: %w", identifier, err)
	}
	if State(currentState) != to {
		if !validTransitions[State(currentState)][to] {
			return fmt.Errorf("transition %s→%s is not valid", currentState, to)
		}
		if actor != "human" && agentForbidden[to] {
			return fmt.Errorf("only humans may transition to %q", to)
		}
		if _, err := tx.Exec(
			`UPDATE issues SET state=?, updated_at=CURRENT_TIMESTAMP WHERE identifier=?`,
			string(to), identifier,
		); err != nil {
			return err
		}
		meta := fmt.Sprintf(`{"from":%q,"to":%q}`, currentState, to)
		if _, err := tx.Exec(
			`INSERT INTO issue_events(id,issue_id,actor,event_type,metadata) VALUES(?,?,?,?,?)`,
			newID(), issueID, actor, "state_change", meta,
		); err != nil {
			return err
		}
	}
	if note != "" {
		if _, err := tx.Exec(
			`INSERT INTO issue_notes(id,issue_id,author,body) VALUES(?,?,?,?)`,
			newID(), issueID, actor, note,
		); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) ListProjects() ([]string, error) {
	rows, err := s.db.Query(`SELECT slug FROM projects ORDER BY slug`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var slug string
		if err := rows.Scan(&slug); err != nil {
			return nil, err
		}
		out = append(out, slug)
	}
	return out, rows.Err()
}

func (s *Store) logEvent(issueID, actor, eventType, metadata string) error {
	_, err := s.db.Exec(
		`INSERT INTO issue_events(id,issue_id,actor,event_type,metadata) VALUES(?,?,?,?,?)`,
		newID(), issueID, actor, eventType, metadata,
	)
	return err
}

type scannable interface{ Scan(dest ...any) error }

func scanIssue(row scannable) (*Issue, error) {
	var i Issue
	var priority sql.NullInt64
	var labels, blockedBy string
	if err := row.Scan(
		&i.ID, &i.Identifier, &i.ProjectSlug, &i.Title, &i.Description,
		&priority, &i.State, &labels, &blockedBy, &i.Assignee,
		&i.CreatedAt, &i.UpdatedAt,
	); err != nil {
		return nil, err
	}
	if priority.Valid {
		v := int(priority.Int64)
		i.Priority = &v
	}
	i.Labels = unmarshalStringArray(labels)
	i.BlockedBy = unmarshalStringArray(blockedBy)
	return &i, nil
}

func newID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func sqlNullInt(p *int) sql.NullInt64 {
	if p == nil {
		return sql.NullInt64{}
	}
	return sql.NullInt64{Valid: true, Int64: int64(*p)}
}

// marshalStringArray serializes a []string to a JSON array for storage. Using
// encoding/json (rather than hand-rolling) lets labels contain any UTF-8
// character — commas, quotes, brackets — without corrupting the round-trip.
func marshalStringArray(ss []string) (string, error) {
	if len(ss) == 0 {
		return "[]", nil
	}
	b, err := json.Marshal(ss)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// unmarshalStringArray parses a JSON array of strings produced by
// marshalStringArray. Returns nil on empty/malformed input — the scanner
// already knows the column is non-null.
func unmarshalStringArray(s string) []string {
	if s == "" || s == "[]" {
		return nil
	}
	var out []string
	if err := json.Unmarshal([]byte(s), &out); err != nil {
		return nil
	}
	return out
}
