package nixwarm

import (
	"context"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestEnsure_CreatesDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "warm")
	w, err := Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := w.Ensure(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(dir); err != nil {
		t.Fatalf("expected dir to exist: %v", err)
	}
}

func TestEnsure_CreatesStoreSubdir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "warm")
	w, _ := Open(dir)
	if err := w.Ensure(); err != nil {
		t.Fatal(err)
	}
	store := filepath.Join(dir, "store")
	if _, err := os.Stat(store); err != nil {
		t.Fatalf("expected store subdir to exist: %v", err)
	}
}

func TestLock_IsExclusive(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "warm")
	w, _ := Open(dir)
	_ = w.Ensure()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	rel1, err := w.Lock(ctx)
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
		rel2, err := w.Lock(ctx2)
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
	dir := filepath.Join(t.TempDir(), "warm")
	w, _ := Open(dir)
	_ = w.Ensure()

	rel1, _ := w.Lock(context.Background())
	_ = rel1()

	// Second lock should succeed immediately after unlock.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	rel2, err := w.Lock(ctx)
	if err != nil {
		t.Fatalf("Lock failed after unlock: %v", err)
	}
	_ = rel2()
}

func TestHasContent_Empty(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "warm")
	w, _ := Open(dir)
	_ = w.Ensure()
	has, err := w.HasContent()
	if err != nil {
		t.Fatal(err)
	}
	if has {
		t.Error("expected empty store")
	}
}

func TestHasContent_WithEntry(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "warm")
	w, _ := Open(dir)
	_ = w.Ensure()
	f, err := os.Create(filepath.Join(dir, "store", "nixpkgs-hello-2.12"))
	if err != nil {
		t.Fatal(err)
	}
	_ = f.Close()
	has, err := w.HasContent()
	if err != nil {
		t.Fatal(err)
	}
	if !has {
		t.Error("expected non-empty store")
	}
}

func TestHasContent_NonExistent(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nonexistent")
	w, _ := Open(dir)
	has, err := w.HasContent()
	if err != nil {
		t.Fatal(err)
	}
	if has {
		t.Error("expected empty for nonexistent dir")
	}
}

func TestOpen_Dir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "warm")
	w, err := Open(dir)
	if err != nil {
		t.Fatal(err)
	}
	if w.Dir != dir {
		t.Errorf("Dir = %q, want %q", w.Dir, dir)
	}
	if w.LockPath != filepath.Join(dir, ".nix-warm.lock") {
		t.Errorf("LockPath = %q, want %q", w.LockPath, filepath.Join(dir, ".nix-warm.lock"))
	}
}
