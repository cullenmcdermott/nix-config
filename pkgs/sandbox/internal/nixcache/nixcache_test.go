package nixcache

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestEnsure_CreatesDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "cache")
	c, err := Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.Ensure(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(dir); err != nil {
		t.Fatalf("expected dir to exist: %v", err)
	}
}

func TestLock_IsExclusive(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "cache")
	c, _ := Open(dir)
	_ = c.Ensure()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	rel1, err := c.Lock(ctx)
	if err != nil {
		t.Fatal(err)
	}

	gotLocked := make(chan time.Duration, 1)
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		start := time.Now()
		ctx2, cancel2 := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel2()
		rel2, err := c.Lock(ctx2)
		if err != nil {
			gotLocked <- 0
			return
		}
		gotLocked <- time.Since(start)
		_ = rel2()
	}()

	time.Sleep(200 * time.Millisecond)
	_ = rel1()
	d := <-gotLocked
	if d < 100*time.Millisecond {
		t.Errorf("second Lock returned too quickly: %v", d)
	}
	wg.Wait()
}

func TestLock_UnlockReleases(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "cache")
	c, _ := Open(dir)
	_ = c.Ensure()

	rel1, _ := c.Lock(context.Background())
	_ = rel1()

	// Second lock should succeed immediately after unlock.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	rel2, err := c.Lock(ctx)
	if err != nil {
		t.Fatalf("Lock failed after unlock: %v", err)
	}
	_ = rel2()
}

func TestOpen_Dir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "cache")
	c, err := Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	if c.Dir != dir {
		t.Errorf("Dir = %q, want %q", c.Dir, dir)
	}
	if c.LockPath != filepath.Join(dir, ".nix-cache.lock") {
		t.Errorf("LockPath = %q, want %q", c.LockPath, filepath.Join(dir, ".nix-cache.lock"))
	}
}

func TestEnsureKey_GeneratesNewKey(t *testing.T) {
	dir := t.TempDir()
	secretPath := filepath.Join(dir, "sub", "nix-cache-key.sec")

	pub, err := EnsureKey(secretPath)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(pub, KeyName+":") {
		t.Errorf("public key prefix wrong: %q", pub)
	}

	// File must exist with mode 0600.
	info, err := os.Stat(secretPath)
	if err != nil {
		t.Fatalf("secret file missing: %v", err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("secret file mode = %v, want 0600", info.Mode().Perm())
	}

	// Contents must match expected secret-key format: name + ":" + base64(64-byte key).
	data, err := os.ReadFile(secretPath)
	if err != nil {
		t.Fatal(err)
	}
	re := regexp.MustCompile(`^sandbox-cache-1:[A-Za-z0-9+/]{86}==$`)
	if !re.Match(data) {
		t.Errorf("secret file content does not match expected regexp; got %q", string(data))
	}

	// Public key must be the last 32 bytes of the secret key, base64-encoded.
	idx := strings.IndexByte(string(data), ':')
	if idx < 0 {
		t.Fatal("secret missing ':'")
	}
	priv, err := base64.StdEncoding.DecodeString(string(data[idx+1:]))
	if err != nil {
		t.Fatal(err)
	}
	if len(priv) != ed25519.PrivateKeySize {
		t.Fatalf("priv length = %d, want %d", len(priv), ed25519.PrivateKeySize)
	}
	wantPub := KeyName + ":" + base64.StdEncoding.EncodeToString(priv[32:])
	if pub != wantPub {
		t.Errorf("public key = %q, want %q (last 32 bytes of priv)", pub, wantPub)
	}
}

func TestEnsureKey_IsIdempotent(t *testing.T) {
	dir := t.TempDir()
	secretPath := filepath.Join(dir, "nix-cache-key.sec")

	pub1, err := EnsureKey(secretPath)
	if err != nil {
		t.Fatal(err)
	}
	// File contents snapshot.
	before, err := os.ReadFile(secretPath)
	if err != nil {
		t.Fatal(err)
	}

	pub2, err := EnsureKey(secretPath)
	if err != nil {
		t.Fatal(err)
	}
	if pub1 != pub2 {
		t.Errorf("second EnsureKey returned different public key:\n  first:  %q\n  second: %q", pub1, pub2)
	}
	// File contents must not change on a second call.
	after, err := os.ReadFile(secretPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(before) != string(after) {
		t.Errorf("secret file was rewritten on second EnsureKey call")
	}
}

func TestEnsureKey_RejectsMalformedFile(t *testing.T) {
	dir := t.TempDir()
	secretPath := filepath.Join(dir, "key.sec")
	if err := os.WriteFile(secretPath, []byte("not-a-real-key"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := EnsureKey(secretPath); err == nil {
		t.Errorf("expected error for malformed secret key file")
	}
}
