package cli_test

import (
	"bytes"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/local-symphony/internal/cli"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/config"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/db"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/project"
)

func newTestDB(t *testing.T) *db.Store {
	t.Helper()
	s, err := db.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("db.Open: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

// runCmd opens a fresh store for each invocation so deferred store.Close()
// in one command doesn't poison the next.
func runCmd(t *testing.T, _ *db.Store, dbPath string, args ...string) string {
	t.Helper()
	cfg := &config.Config{Port: 7437, DataDir: filepath.Dir(dbPath)}
	var buf bytes.Buffer
	fs, err := db.Open(dbPath)
	if err != nil {
		t.Fatalf("db.Open: %v", err)
	}
	err = cli.RunWithStore(fs, cfg, &buf, args)
	fs.Close()
	if err != nil {
		t.Fatalf("RunWithStore(%v): %v", args, err)
	}
	return buf.String()
}

func TestAddAndList(t *testing.T) {
	t.Setenv("SYMPHONY_PROJECT", "test")
	dbPath := filepath.Join(t.TempDir(), "test.db")
	store := newTestDB(t)
	_ = store // used for TempDir reference

	// Debug: check what Detect() returns
	t.Logf("Detect() = %q", project.Detect())

	// Debug: direct DB check before
	fs, _ := db.Open(dbPath)
	issues, _ := fs.ListIssues(db.ListIssuesOpts{})
	t.Logf("Direct DB before add: %d issues (all projects)", len(issues))
	fs.Close()

	out := runCmd(t, store, dbPath, "add", "My first issue")
	t.Logf("add output: %q", out)
	if !strings.Contains(out, "TEST-001") {
		t.Errorf("expected TEST-001 in output, got: %q", out)
	}

	// Debug: check Detect again
	t.Logf("Detect() after add = %q", project.Detect())

	// Debug: direct DB check after add
	fs2, _ := db.Open(dbPath)
	issues2, _ := fs2.ListIssues(db.ListIssuesOpts{})
	t.Logf("Direct DB after add: %d issues (all projects)", len(issues2))
	for _, i := range issues2 {
		t.Logf("  - %s project=%q", i.Identifier, i.ProjectSlug)
	}
	fs2.Close()

	out = runCmd(t, store, dbPath, "ls")
	t.Logf("ls output: %q", out)
	if !strings.Contains(out, "My first issue") {
		t.Errorf("expected issue title in ls output, got: %q", out)
	}
}

func TestGetIssue(t *testing.T) {
	t.Setenv("SYMPHONY_PROJECT", "test")
	dbPath := filepath.Join(t.TempDir(), "test.db")
	store := newTestDB(t)
	_ = store

	runCmd(t, store, dbPath, "add", "Detail issue", "--desc", "Some description")
	out := runCmd(t, store, dbPath, "get", "TEST-001")
	if !strings.Contains(out, "Detail issue") {
		t.Errorf("expected title in get output: %q", out)
	}
	if !strings.Contains(out, "Some description") {
		t.Errorf("expected description in get output: %q", out)
	}
}

func TestMoveState(t *testing.T) {
	t.Setenv("SYMPHONY_PROJECT", "test")
	dbPath := filepath.Join(t.TempDir(), "test.db")
	store := newTestDB(t)
	_ = store

	runCmd(t, store, dbPath, "add", "Move me", "--state", "backlog")
	runCmd(t, store, dbPath, "mv", "TEST-001", "in_progress")

	out := runCmd(t, store, dbPath, "get", "TEST-001")
	if !strings.Contains(out, "in_progress") {
		t.Errorf("expected in_progress state in output: %q", out)
	}
}

func TestHandoff(t *testing.T) {
	t.Setenv("SYMPHONY_PROJECT", "test")
	dbPath := filepath.Join(t.TempDir(), "test.db")
	store := newTestDB(t)
	_ = store

	runCmd(t, store, dbPath, "add", "Long task", "--state", "backlog")
	runCmd(t, store, dbPath, "mv", "TEST-001", "in_progress")
	out := runCmd(t, store, dbPath, "handoff", "TEST-001", "Completed auth module. Remaining: wire HTTP handlers.")

	if !strings.Contains(out, "TEST-001") {
		t.Errorf("expected identifier in handoff output: %q", out)
	}

	// Verify state is paused and note was added (check via fresh store)
	fs, _ := db.Open(dbPath)
	defer fs.Close()
	issue, err := fs.GetIssue("TEST-001")
	if err != nil {
		t.Fatalf("GetIssue: %v", err)
	}
	if issue.State != db.StatePaused {
		t.Errorf("state: got %q want paused", issue.State)
	}
	notes, _ := fs.ListNotes("TEST-001")
	if len(notes) == 0 {
		t.Error("expected handoff note")
	}
}