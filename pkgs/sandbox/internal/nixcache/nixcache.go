// Package nixcache manages the host-side shared Nix binary cache directory and
// its signing key. The cache lives at a well-known XDG data path and is
// populated by `nix copy` from running VMs over SSH.
//
// Strategy: RO-mount the cache at /var/sandbox/nix-cache inside each VM and
// configure nix-daemon to use it as a substituter with the matching public
// signing key. Sync from the VM via SSH before stop/destroy while the VM is
// still reachable.
package nixcache

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"golang.org/x/sys/unix"
)

// KeyName is the prefix used for the signing key. The full key string is
// "<KeyName>:<base64>" — matching the format Nix uses.
const KeyName = "sandbox-cache-1"

// Cache manages the host-side shared binary cache.
type Cache struct {
	// Dir is the root of the binary cache (e.g. ~/.local/share/sandbox/nix-cache/).
	Dir string
	// LockPath is the advisory lock file path.
	LockPath string
}

// Open returns a Cache handle for the given directory. It does not create or
// lock anything — call Ensure before the first use and Lock before syncing.
func Open(dir string) (*Cache, error) {
	return &Cache{
		Dir:      dir,
		LockPath: filepath.Join(dir, ".nix-cache.lock"),
	}, nil
}

// Ensure creates the binary cache directory. Idempotent.
func (c *Cache) Ensure() error {
	return os.MkdirAll(c.Dir, 0o755)
}

// Lock acquires an exclusive advisory lock on the cache's lockfile, blocking
// until acquired or the context is cancelled. The returned release function
// must be called to drop the lock.
//
// Note: because flock(2) cannot be interrupted by closing its file descriptor
// on macOS, if the context is cancelled while a competing process holds the
// lock, this call will block until that process releases it. Production code
// should use a reasonably short timeout on the context.
func (c *Cache) Lock(ctx context.Context) (release func() error, err error) {
	if err := c.Ensure(); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(c.LockPath, os.O_CREATE|os.O_RDWR, 0o600)
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

// EnsureKey makes sure the signing secret key file at secretPath exists, and
// returns the corresponding public key string in Nix's "<name>:<base64>" form.
//
// If the file exists it is parsed and validated (must be "name:base64" with a
// decoded length of 64 bytes — Go's crypto/ed25519 PrivateKey layout is
// seed||public, which matches libsodium and what `nix key generate-secret`
// emits). If it does not exist, a fresh ed25519 keypair is generated and the
// secret is written with mode 0600 (creating the parent dir if needed).
func EnsureKey(secretPath string) (publicKey string, err error) {
	data, rerr := os.ReadFile(secretPath)
	if rerr == nil {
		name, priv, perr := parseSecretKey(string(data))
		if perr != nil {
			return "", fmt.Errorf("parse secret key %s: %w", secretPath, perr)
		}
		pub := priv[32:]
		return name + ":" + base64.StdEncoding.EncodeToString(pub), nil
	}
	if !os.IsNotExist(rerr) {
		return "", rerr
	}

	if err := os.MkdirAll(filepath.Dir(secretPath), 0o700); err != nil {
		return "", err
	}
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return "", fmt.Errorf("ed25519 keygen: %w", err)
	}
	secret := KeyName + ":" + base64.StdEncoding.EncodeToString(priv)
	if err := os.WriteFile(secretPath, []byte(secret), 0o600); err != nil {
		return "", err
	}
	return KeyName + ":" + base64.StdEncoding.EncodeToString(pub), nil
}

// parseSecretKey parses a "name:base64" secret-key string and validates it
// decodes to a 64-byte ed25519 private key.
func parseSecretKey(s string) (name string, priv ed25519.PrivateKey, err error) {
	s = strings.TrimSpace(s)
	i := strings.IndexByte(s, ':')
	if i <= 0 {
		return "", nil, fmt.Errorf("missing 'name:' prefix")
	}
	name = s[:i]
	raw, derr := base64.StdEncoding.DecodeString(s[i+1:])
	if derr != nil {
		return "", nil, fmt.Errorf("base64: %w", derr)
	}
	if len(raw) != ed25519.PrivateKeySize {
		return "", nil, fmt.Errorf("expected %d-byte key, got %d", ed25519.PrivateKeySize, len(raw))
	}
	return name, ed25519.PrivateKey(raw), nil
}

// Sync invokes `nix copy` to pull all store paths from the VM's nix-daemon
// (reached via ssh-ng) into the local file:// binary cache. NIX_SSHOPTS is set
// so the nix-launched ssh uses our Lima-generated ssh config.
//
// The copy deliberately does NOT re-sign paths. An earlier version signed every
// pulled path with the host cache key — which every VM trusts — but the VM is
// untrusted: a compromised agent in one VM could serve a poisoned NAR for a
// legitimate store path, the host would re-sign it, and every other VM would
// then substitute the attacker's content as trusted. With re-signing removed,
// pulled paths keep whatever upstream signature they already carry
// (cache.nixos.org, flox); a poisoned or VM-local path lands unsigned, and each
// consuming VM's require-sigs rejects anything not signed by a trusted key.
//
// --no-check-sigs governs only what we accept INTO the cache, not what
// consumers trust. It is retained so `nix copy --all` does not abort on the
// VM's locally-built (unsigned) paths; a tampered path bearing a forged
// signature string is still rejected downstream when that signature fails to
// verify against a trusted public key.
func Sync(ctx context.Context, sshConfigFile, sshHost, cacheDir string, stdout, stderr io.Writer) error {
	to := "file://" + cacheDir
	cmd := exec.CommandContext(ctx,
		"nix",
		"--extra-experimental-features", "nix-command",
		"copy",
		"--no-check-sigs",
		"--from", "ssh-ng://"+sshHost,
		"--all",
		"--to", to,
	)
	cmd.Env = append(os.Environ(), "NIX_SSHOPTS=-F "+sshConfigFile)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	return cmd.Run()
}
