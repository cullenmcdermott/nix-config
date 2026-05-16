// Package mutagen wraps the mutagen CLI with the small set of operations
// sandbox needs: create per-VM project + transcripts sessions, list them,
// pause/resume, and terminate.
package mutagen

import (
	"context"
	"fmt"
	"path"
	"strings"
)

type Manager struct{ r Runner }

func New(r Runner) *Manager { return &Manager{r: r} }

type Spec struct {
	VMID        string // e.g. "demo-abcdef"
	HostPath    string // host-side absolute path (project sync only)
	VMPath      string // VM-side absolute path (project sync only)
	HomeDir     string // host home, used for transcripts (e.g. "/Users/alice")
	LimaSSHHost string // ssh alias from lima.SSHConfig.Host
	VMHome      string // VM-side home dir (e.g. "/home/alice.linux"), used for transcript paths
}

func sessionLabel(vmID string) string { return "sandbox-vm-id=" + vmID }

// EnsureDaemon runs `mutagen daemon start`. The daemon is required for any
// `sync` subcommand to work. This is idempotent: Mutagen's daemon start exits
// 0 (with a "daemon is already running" message) when the daemon is already up.
// First-time users frequently hit a confusing "no daemon" error otherwise (E-I-4).
func (m *Manager) EnsureDaemon(ctx context.Context) error {
	if _, err := m.r.Output(ctx, nil, "daemon", "start"); err != nil {
		return fmt.Errorf("mutagen daemon start: %w", err)
	}
	return nil
}

func (m *Manager) CreateProject(ctx context.Context, s Spec) error {
	args := []string{
		"sync", "create",
		"--name=sandbox-" + s.VMID + "-project",
		"--label", sessionLabel(s.VMID),
		"--mode=two-way-resolved",
		"--ignore-vcs",
		s.HostPath, s.LimaSSHHost + ":" + s.VMPath,
	}
	_, err := m.r.Output(ctx, nil, args...)
	return err
}

// TranscriptSubs is the canonical set of ~/.claude subdirectories synced one-way
// from the VM back to the host (transcripts of agent activity).
var TranscriptSubs = []string{"projects", "todos"}

// CreateTranscripts creates one-way-safe sync sessions for the named subs.
// Pass the full TranscriptSubs list on first boot, or only the missing names
// when reconciling a partially-created set (NEW-I-2). Mutagen errors on
// duplicate session names, so the caller must not include subs that already
// exist.
func (m *Manager) CreateTranscripts(ctx context.Context, s Spec, subs []string) error {
	if s.VMHome == "" {
		return fmt.Errorf("VMHome is required for transcript path construction")
	}
	for _, sub := range subs {
		hostPath := path.Join(s.HomeDir, ".claude", sub)
		vmPath := path.Join(s.VMHome, ".claude", sub)
		args := []string{
			"sync", "create",
			"--name=sandbox-" + s.VMID + "-transcripts-" + sub,
			"--label", sessionLabel(s.VMID),
			"--mode=one-way-safe",
			s.LimaSSHHost + ":" + vmPath, hostPath,
		}
		if _, err := m.r.Output(ctx, nil, args...); err != nil {
			return err
		}
	}
	return nil
}

type Session struct {
	Name   string
	Status string
}

// sessionListTemplate emits "name|status" per session. Mutagen has no `--json`
// flag (removed pre-0.18); `--template` is the supported way to get
// machine-parseable output. We use a pipe delimiter because session names
// don't contain pipes.
const sessionListTemplate = `{{range .}}{{.Name}}|{{.Status}}` + "\n" + `{{end}}`

func (m *Manager) SessionsFor(ctx context.Context, vmID string) ([]Session, error) {
	out, err := m.r.Output(ctx, nil,
		"sync", "list",
		"--label-selector="+sessionLabel(vmID),
		"--template", sessionListTemplate,
	)
	if err != nil {
		return nil, fmt.Errorf("mutagen sync list: %w", err)
	}
	trimmed := strings.TrimSpace(string(out))
	if trimmed == "" {
		return nil, nil
	}
	var sessions []Session
	for _, line := range strings.Split(trimmed, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		name, status, _ := strings.Cut(line, "|")
		sessions = append(sessions, Session{Name: name, Status: status})
	}
	return sessions, nil
}

func (m *Manager) PauseAll(ctx context.Context, vmID string) error {
	_, err := m.r.Output(ctx, nil,
		"sync", "pause", "--label-selector="+sessionLabel(vmID))
	return err
}

func (m *Manager) ResumeAll(ctx context.Context, vmID string) error {
	_, err := m.r.Output(ctx, nil,
		"sync", "resume", "--label-selector="+sessionLabel(vmID))
	return err
}

func (m *Manager) TerminateAll(ctx context.Context, vmID string) error {
	_, err := m.r.Output(ctx, nil,
		"sync", "terminate", "--label-selector="+sessionLabel(vmID))
	if err != nil && strings.Contains(err.Error(), "not found") {
		return nil
	}
	return err
}
