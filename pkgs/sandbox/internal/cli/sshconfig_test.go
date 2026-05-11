package cli

import (
	"os"
	"path/filepath"
	"testing"
)

func TestEnsureSSHConfigInclude_CreatesConfigFromScratch(t *testing.T) {
	home := t.TempDir()

	if err := ensureSSHConfigInclude(home); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(home, ".ssh", "config"))
	if err != nil {
		t.Fatal(err)
	}
	got := string(data)
	if got != sshIncludeLine+"\n" {
		t.Errorf("expected %q, got %q", sshIncludeLine+"\n", got)
	}

	// Verify directory permissions.
	info, err := os.Stat(filepath.Join(home, ".ssh"))
	if err != nil {
		t.Fatal(err)
	}
	if perm := info.Mode().Perm(); perm != 0o700 {
		t.Errorf("expected .ssh dir perms 0700, got %o", perm)
	}
}

func TestEnsureSSHConfigInclude_PrependsToExisting(t *testing.T) {
	home := t.TempDir()
	sshDir := filepath.Join(home, ".ssh")
	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		t.Fatal(err)
	}
	existing := "Host *\n\tIdentityAgent foo\n"
	if err := os.WriteFile(filepath.Join(sshDir, "config"), []byte(existing), 0o600); err != nil {
		t.Fatal(err)
	}

	if err := ensureSSHConfigInclude(home); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(sshDir, "config"))
	if err != nil {
		t.Fatal(err)
	}
	got := string(data)
	want := sshIncludeLine + "\n\n" + existing
	if got != want {
		t.Errorf("mismatch:\nwant: %q\n got: %q", want, got)
	}
}

func TestEnsureSSHConfigInclude_Idempotent(t *testing.T) {
	home := t.TempDir()
	sshDir := filepath.Join(home, ".ssh")
	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		t.Fatal(err)
	}
	content := sshIncludeLine + "\n\nHost *\n\tIdentityAgent foo\n"
	if err := os.WriteFile(filepath.Join(sshDir, "config"), []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}

	if err := ensureSSHConfigInclude(home); err != nil {
		t.Fatal(err)
	}

	data, err := os.ReadFile(filepath.Join(sshDir, "config"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != content {
		t.Errorf("file should be unchanged:\nwant: %q\n got: %q", content, string(data))
	}
}
