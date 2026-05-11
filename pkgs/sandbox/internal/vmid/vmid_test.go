package vmid

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestForPath_Stable(t *testing.T) {
	a := ForPath("/Users/alice/src/myproject")
	b := ForPath("/Users/alice/src/myproject")
	if a != b {
		t.Fatalf("ForPath not deterministic: %q vs %q", a, b)
	}
}

func TestForPath_FormatAndUniqueness(t *testing.T) {
	id := ForPath("/Users/alice/src/my-project")
	parts := strings.Split(string(id), "-")
	if len(parts) < 2 {
		t.Fatalf("expected `<slug>-<hash>`, got %q", id)
	}
	hash := parts[len(parts)-1]
	if len(hash) != 6 {
		t.Fatalf("expected 6-char hash suffix, got %q (len %d)", hash, len(hash))
	}
	slug := strings.Join(parts[:len(parts)-1], "-")
	if slug != "my-project" {
		t.Fatalf("expected slug 'my-project', got %q", slug)
	}

	other := ForPath("/Users/alice/src/my-project-2")
	if other == id {
		t.Fatalf("different paths produced same id")
	}
}

func TestForPath_Sanitization(t *testing.T) {
	id := ForPath("/Users/alice/src/My Project (work)!")
	if strings.ContainsAny(string(id), " ()!") {
		t.Fatalf("unsanitized chars in id: %q", id)
	}
}

func TestForCwd_FallsBackToCwdOutsideGit(t *testing.T) {
	dir := t.TempDir()
	cwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(cwd) }()
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	got, err := ForCwd()
	if err != nil {
		t.Fatal(err)
	}
	resolvedDir, _ := filepath.EvalSymlinks(dir)
	want := ForPath(resolvedDir)
	if got != want {
		t.Fatalf("ForCwd outside git = %q, want %q", got, want)
	}
}

func TestForCwd_UsesGitToplevel(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
	root := t.TempDir()
	for _, args := range [][]string{
		{"init"}, {"config", "user.email", "t@t"}, {"config", "user.name", "t"},
	} {
		c := exec.Command("git", args...)
		c.Dir = root
		if out, err := c.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	sub := filepath.Join(root, "subdir")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	cwd, _ := os.Getwd()
	defer func() { _ = os.Chdir(cwd) }()
	if err := os.Chdir(sub); err != nil {
		t.Fatal(err)
	}
	id, err := ForCwd()
	if err != nil {
		t.Fatal(err)
	}
	resolvedRoot, _ := filepath.EvalSymlinks(root)
	want := ForPath(resolvedRoot)
	if id != want {
		t.Fatalf("ForCwd in subdir of git repo = %q, want %q", id, want)
	}
}
