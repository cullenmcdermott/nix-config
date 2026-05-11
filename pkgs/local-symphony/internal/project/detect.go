package project

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const maxSlugLen = 64

// Detect returns the active project slug using a priority chain:
//  1. $SYMPHONY_PROJECT env var (set by sandbox or user)
//  2. .symphony file in cwd or any parent — walk stops at git toplevel or $HOME
//  3. basename of `git rev-parse --show-toplevel` (handles worktrees correctly)
//  4. basename of cwd (last resort — can collide between repos with the same name)
//  5. "inbox"
//
// Note on collisions: the cwd-basename fallback can map two different repos with the
// same directory name to the same slug. If that matters, set $SYMPHONY_PROJECT or drop
// a .symphony file in the repo root.
func Detect() string {
	if p := os.Getenv("SYMPHONY_PROJECT"); p != "" {
		return slugify(p)
	}
	if p := findMarkerFile(); p != "" {
		return slugify(strings.TrimSpace(p))
	}
	if p := fromGitToplevel(); p != "" {
		return slugify(p)
	}
	if cwd, err := os.Getwd(); err == nil {
		return slugify(filepath.Base(cwd))
	}
	return "inbox"
}

// findMarkerFile walks parents looking for a `.symphony` file, but stops at the git
// toplevel (so a hostile parent dir cannot inject a project name into an unrelated
// repo) or at $HOME (so we never read marker files from /tmp, /, etc).
func findMarkerFile() string {
	dir, err := os.Getwd()
	if err != nil {
		return ""
	}
	stop := walkStopDir()
	for {
		path := filepath.Join(dir, ".symphony")
		if data, err := os.ReadFile(path); err == nil {
			return strings.TrimSpace(string(data))
		}
		if stop != "" && dir == stop {
			return ""
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

// walkStopDir returns the path where findMarkerFile should stop ascending — the git
// toplevel if we are in a git repo, otherwise $HOME. Returns "" if neither is known
// (in which case the walk falls back to terminating at filesystem root, matching the
// previous behavior).
func walkStopDir() string {
	if out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output(); err == nil {
		top := strings.TrimSpace(string(out))
		if top != "" {
			// Stop AT the parent of toplevel — i.e. don't walk above the repo root.
			return filepath.Dir(top)
		}
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		return filepath.Dir(home)
	}
	return ""
}

// fromGitToplevel returns the basename of the repo root. This is preferred over
// parsing `git remote get-url origin` because:
//   - It works in repos with no remote, multiple remotes, or non-`origin` primaries.
//   - It works in worktrees (where the cwd basename is the worktree name, not the repo).
//   - It cannot be poisoned by a hostile `.git/config` remote URL.
func fromGitToplevel() string {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return ""
	}
	top := strings.TrimSpace(string(out))
	if top == "" {
		return ""
	}
	return filepath.Base(top)
}

// slugify lowercases and replaces non-alphanumeric (except hyphen) with hyphen,
// then caps length at maxSlugLen to bound on-disk identifiers.
func slugify(s string) string {
	s = strings.ToLower(s)
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			b.WriteRune(r)
		} else {
			b.WriteRune('-')
		}
	}
	out := strings.Trim(b.String(), "-")
	if len(out) > maxSlugLen {
		out = strings.TrimRight(out[:maxSlugLen], "-")
	}
	return out
}
