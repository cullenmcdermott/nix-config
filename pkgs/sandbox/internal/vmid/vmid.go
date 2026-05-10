// Package vmid derives a stable per-project VM identifier.
//
// Inside a git repo: <sanitized-basename(toplevel)>-<6-char-sha256(toplevel)>.
// Outside a git repo: <sanitized-basename(cwd)>-<6-char-sha256(cwd)>.
package vmid

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

type ID string

func (i ID) String() string { return string(i) }

var sanitize = regexp.MustCompile(`[^a-zA-Z0-9._-]+`)

// ForPath computes the VM id for an absolute path. It does not consult git.
func ForPath(absPath string) ID {
	clean := filepath.Clean(absPath)
	base := filepath.Base(clean)
	slug := strings.Trim(sanitize.ReplaceAllString(base, "-"), "-")
	if slug == "" {
		slug = "project"
	}
	sum := sha256.Sum256([]byte(clean))
	return ID(fmt.Sprintf("%s-%s", strings.ToLower(slug), hex.EncodeToString(sum[:])[:6]))
}

// ForCwd is the production entrypoint: prefers the git toplevel, falls back
// to the cwd if not in a git repo.
func ForCwd() (ID, error) {
	if root, ok := gitToplevel(); ok {
		return ForPath(root), nil
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("getwd: %w", err)
	}
	resolved, err := filepath.EvalSymlinks(cwd)
	if err != nil {
		resolved = cwd
	}
	return ForPath(resolved), nil
}

// ProjectPath returns the absolute project root used for mounts: git toplevel
// if available, else cwd. Symlinks resolved.
func ProjectPath() (string, error) {
	if root, ok := gitToplevel(); ok {
		return root, nil
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	if r, err := filepath.EvalSymlinks(cwd); err == nil {
		return r, nil
	}
	return cwd, nil
}

func gitToplevel() (string, bool) {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err != nil {
		return "", false
	}
	root := strings.TrimSpace(string(out))
	if root == "" {
		return "", false
	}
	if resolved, err := filepath.EvalSymlinks(root); err == nil {
		return resolved, true
	}
	return root, true
}
