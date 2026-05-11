// Package nixwarm manages the host-side warm /nix template directory and its
// advisory lock. The warm template lives at a well-known XDG data path and is
// seeded by merging /nix/store from destroyed VMs back into it.
//
// Strategy: RO-mount the warm template at /var/sandbox/warm-nix/ inside each VM
// and rsync its store into the freshly-provisioned /nix/store. Merge on destroy
// via SSH while the VM is still reachable.
package nixwarm

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"golang.org/x/sys/unix"
)

// Warm manages the warm /nix template on the host.
type Warm struct {
	// Dir is the root of the warm template (e.g. ~/.local/share/sandbox/nix-warm/).
	Dir string
	// LockPath is the advisory lock file path.
	LockPath string
}

// Open returns a Warm handle for the given directory. It does not create or
// lock anything — call Ensure before the first use and Lock before merging.
func Open(dir string) (*Warm, error) {
	return &Warm{
		Dir:      dir,
		LockPath: filepath.Join(dir, ".nix-warm.lock"),
	}, nil
}

// Ensure creates the warm template directory and its store subdirectory.
// Idempotent.
func (w *Warm) Ensure() error {
	if err := os.MkdirAll(w.Dir, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(w.Dir, "store"), 0o755); err != nil {
		return err
	}
	return nil
}

// Lock acquires an exclusive advisory lock on the warm template's lockfile,
// blocking until acquired or the context is cancelled. The returned release
// function must be called to drop the lock.
//
// Note: because flock(2) cannot be interrupted by closing its file descriptor
// on macOS, if the context is cancelled while a competing process holds the
// lock, this call will block until that process releases it. Production code
// should use a reasonably short timeout on the context.
func (w *Warm) Lock(ctx context.Context) (release func() error, err error) {
	if err := w.Ensure(); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(w.LockPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	fd := int(f.Fd())

	// Try to acquire the lock synchronously first — if the lock is free this
	// avoids the goroutine overhead entirely.
	err = unix.Flock(fd, unix.LOCK_EX)
	if err == nil {
		return func() error {
			_ = unix.Flock(fd, unix.LOCK_UN)
			return f.Close()
		}, nil
	}
	// Lock is held by another process. Launch a background goroutine that will
	// eventually acquire it, and wait for either context cancellation or the
	// lock being acquired.
	var wg sync.WaitGroup
	wg.Add(1)
	errc := make(chan error, 1)
	go func() {
		defer wg.Done()
		errc <- unix.Flock(fd, unix.LOCK_EX)
	}()

	select {
	case err := <-errc:
		if err != nil {
			_ = f.Close()
			return nil, fmt.Errorf("flock: %w", err)
		}
		return func() error {
			_ = unix.Flock(fd, unix.LOCK_UN)
			return f.Close()
		}, nil
	case <-ctx.Done():
		// Cannot interrupt the blocking goroutine. Best effort: wait for it,
		// close the fd (no-op on blocked syscall), return the context error.
		wg.Wait()
		_ = f.Close()
		return nil, ctx.Err()
	}
}

// HasContent reports whether the warm template's store directory has at least
// one entry. Used to gate whether a VM seeds from the warm template.
func (w *Warm) HasContent() (bool, error) {
	entries, err := os.ReadDir(filepath.Join(w.Dir, "store"))
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	return len(entries) > 0, nil
}
