package db_test

import (
	"errors"
	"sync"
	"testing"

	"github.com/cullenmcdermott/system-config/local-symphony/internal/db"
)

func open(t *testing.T) *db.Store {
	t.Helper()
	s, err := db.Open(t.TempDir() + "/test.db")
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func TestIssueRoundtrip(t *testing.T) {
	s := open(t)
	issue := &db.Issue{
		ProjectSlug: "test",
		Title:       "Hello world",
		Description: "A test issue",
		State:       db.StateBacklog,
	}
	if err := s.CreateIssue(issue); err != nil {
		t.Fatalf("CreateIssue: %v", err)
	}
	if issue.Identifier == "" {
		t.Fatal("expected identifier after create")
	}
	got, err := s.GetIssue(issue.Identifier)
	if err != nil {
		t.Fatalf("GetIssue: %v", err)
	}
	if got.Title != issue.Title {
		t.Errorf("Title: got %q want %q", got.Title, issue.Title)
	}
}

func TestStateMachine(t *testing.T) {
	s := open(t)

	tests := []struct {
		name      string
		from      db.State
		to        db.State
		actor     string
		wantError bool
	}{
		// Agent-allowed transitions
		{"agent: backlog→in_progress", db.StateBacklog, db.StateInProgress, "agent", false},
		{"agent: in_progress→human_review", db.StateInProgress, db.StateHumanReview, "agent", false},
		{"agent: in_progress→paused", db.StateInProgress, db.StatePaused, "agent", false},
		// Human-only transitions — agent must be rejected
		{"agent cannot: done", db.StateHumanReview, db.StateDone, "agent", true},
		{"agent cannot: cancelled", db.StateBacklog, db.StateCancelled, "agent", true},
		// Human can do anything
		{"human: human_review→done", db.StateHumanReview, db.StateDone, "human", false},
		{"human: backlog→cancelled", db.StateBacklog, db.StateCancelled, "human", false},
		{"human: cancelled→backlog (reopen)", db.StateCancelled, db.StateBacklog, "human", false},
		// Invalid transitions
		{"invalid: done→backlog", db.StateDone, db.StateBacklog, "human", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			issue := &db.Issue{ProjectSlug: "test", Title: tt.name, State: tt.from}
			if err := s.CreateIssue(issue); err != nil {
				t.Fatalf("CreateIssue: %v", err)
			}
			err := s.UpdateIssueState(issue.Identifier, tt.to, tt.actor)
			if (err != nil) != tt.wantError {
				t.Errorf("UpdateIssueState(%s→%s, actor=%s) error=%v, wantError=%v",
					tt.from, tt.to, tt.actor, err, tt.wantError)
			}
		})
	}
}

// TestNoOpTransition: moving to the current state returns ErrNoOpTransition,
// distinguishable from "invalid transition". Callers can swallow it.
func TestNoOpTransition(t *testing.T) {
	s := open(t)
	issue := &db.Issue{ProjectSlug: "test", Title: "no-op", State: db.StateInProgress}
	if err := s.CreateIssue(issue); err != nil {
		t.Fatalf("CreateIssue: %v", err)
	}
	err := s.UpdateIssueState(issue.Identifier, db.StateInProgress, "agent")
	if !errors.Is(err, db.ErrNoOpTransition) {
		t.Errorf("expected ErrNoOpTransition, got %v", err)
	}
}

// TestConcurrentCreate: two goroutines creating issues in the same project must
// not collide on the identifier. With the per-project counter table this is
// race-free; without it, COUNT(*) would produce duplicates.
func TestConcurrentCreate(t *testing.T) {
	s := open(t)
	const n = 20
	var wg sync.WaitGroup
	errs := make(chan error, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			errs <- s.CreateIssue(&db.Issue{ProjectSlug: "race", Title: "x", State: db.StateBacklog})
		}()
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Errorf("CreateIssue: %v", err)
		}
	}
	issues, err := s.ListIssues(db.ListIssuesOpts{ProjectSlug: "race"})
	if err != nil {
		t.Fatalf("ListIssues: %v", err)
	}
	if len(issues) != n {
		t.Fatalf("expected %d issues, got %d", n, len(issues))
	}
	seen := map[string]bool{}
	for _, i := range issues {
		if seen[i.Identifier] {
			t.Errorf("duplicate identifier %q", i.Identifier)
		}
		seen[i.Identifier] = true
	}
}

// TestLabelRoundtrip: labels with commas, quotes, and brackets survive the
// JSON-encoded storage round-trip. The previous hand-rolled parser corrupted
// any label containing a comma.
func TestLabelRoundtrip(t *testing.T) {
	s := open(t)
	want := []string{"area: backend, urgent", `quote "inside"`, "[brackets]"}
	issue := &db.Issue{ProjectSlug: "test", Title: "labels", State: db.StateBacklog, Labels: want}
	if err := s.CreateIssue(issue); err != nil {
		t.Fatalf("CreateIssue: %v", err)
	}
	got, err := s.GetIssue(issue.Identifier)
	if err != nil {
		t.Fatalf("GetIssue: %v", err)
	}
	if len(got.Labels) != len(want) {
		t.Fatalf("labels length: got %d want %d", len(got.Labels), len(want))
	}
	for i := range want {
		if got.Labels[i] != want[i] {
			t.Errorf("labels[%d]: got %q want %q", i, got.Labels[i], want[i])
		}
	}
}

// TestUpdateIssueIgnoresUnknownColumns: only the allowlist columns may be
// written; arbitrary keys are silently dropped (no SQL injection through map keys).
func TestUpdateIssueIgnoresUnknownColumns(t *testing.T) {
	s := open(t)
	issue := &db.Issue{ProjectSlug: "test", Title: "before", State: db.StateBacklog}
	if err := s.CreateIssue(issue); err != nil {
		t.Fatalf("CreateIssue: %v", err)
	}
	// "title" is allowed; "state" and "deleted_at = NULL); DROP TABLE issues" are not.
	if err := s.UpdateIssue(issue.Identifier, map[string]any{
		"title": "after",
		"state": "done",
		`x"; DROP TABLE issues; --`: "anything",
	}); err != nil {
		t.Fatalf("UpdateIssue: %v", err)
	}
	got, err := s.GetIssue(issue.Identifier)
	if err != nil {
		t.Fatalf("GetIssue: %v", err)
	}
	if got.Title != "after" {
		t.Errorf("title: got %q want %q", got.Title, "after")
	}
	if got.State != db.StateBacklog {
		t.Errorf("state should not have moved via UpdateIssue: got %q", got.State)
	}
}

func TestPausedHandoff(t *testing.T) {
	s := open(t)
	issue := &db.Issue{ProjectSlug: "test", Title: "Handoff test", State: db.StateInProgress}
	if err := s.CreateIssue(issue); err != nil {
		t.Fatalf("CreateIssue: %v", err)
	}
	if err := s.UpdateIssueState(issue.Identifier, db.StatePaused, "agent"); err != nil {
		t.Fatalf("pause: %v", err)
	}
	if err := s.AddNote(issue.Identifier, "agent", "Paused at step 2/5. Auth module done, need to wire handlers."); err != nil {
		t.Fatalf("AddNote: %v", err)
	}
	// Verify note is there
	notes, err := s.ListNotes(issue.Identifier)
	if err != nil {
		t.Fatalf("ListNotes: %v", err)
	}
	if len(notes) != 1 {
		t.Fatalf("expected 1 note, got %d", len(notes))
	}
	// Resume
	if err := s.UpdateIssueState(issue.Identifier, db.StateInProgress, "agent"); err != nil {
		t.Fatalf("resume: %v", err)
	}
}

func TestListIssues(t *testing.T) {
	s := open(t)
	for _, title := range []string{"A", "B", "C"} {
		if err := s.CreateIssue(&db.Issue{ProjectSlug: "proj", Title: title, State: db.StateBacklog}); err != nil {
			t.Fatalf("CreateIssue %q: %v", title, err)
		}
	}
	// Different project — should not appear
	if err := s.CreateIssue(&db.Issue{ProjectSlug: "other", Title: "D", State: db.StateBacklog}); err != nil {
		t.Fatalf("CreateIssue D: %v", err)
	}

	issues, err := s.ListIssues(db.ListIssuesOpts{ProjectSlug: "proj"})
	if err != nil {
		t.Fatalf("ListIssues: %v", err)
	}
	if len(issues) != 3 {
		t.Fatalf("expected 3 issues, got %d", len(issues))
	}
}