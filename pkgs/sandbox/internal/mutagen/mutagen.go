// Package mutagen wraps the mutagen CLI with the small set of operations
// sandbox needs: create per-VM project + transcripts sessions, list them,
// pause/resume, and terminate.
package mutagen

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"path"
	"strings"
)

type Manager struct{ r Runner }

func New(r Runner) *Manager { return &Manager{r: r} }

type Spec struct {
	VMID          string // e.g. "demo-abcdef"
	HostPath      string // host-side absolute path (project sync only)
	VMPath        string // VM-side absolute path (project sync only)
	HomeDir       string // host home, used for transcripts (e.g. "/Users/alice")
	LimaSSHHost   string // ssh alias from lima.SSHConfig.Host
	LimaSSHConfig string // path to Lima's ssh.config (for hostname resolution)
	VMUser        string // VM username (e.g. from $USER), used for transcript paths
}

func sessionLabel(vmID string) string { return "sandbox-vm-id=" + vmID }

// sshCommandFor returns the ssh command with Lima's config file prepended.
// This ensures the Lima SSH alias (e.g. lima-sandbox-<id>) resolves correctly.
func sshCommandFor(configFile string) string {
	if configFile == "" {
		return ""
	}
	return fmt.Sprintf("ssh -F %s", configFile)
}

// EnsureDaemon runs `mutagen daemon start`. The daemon is required for any
// `sync` subcommand to work. This is idempotent: Mutagen's daemon start exits
// 0 (with a "daemon is already running" message) when the daemon is already up.
// First-time users frequently hit a confusing "no daemon" error otherwise (E-I-4).
func (m *Manager) EnsureDaemon(ctx context.Context) error {
	if err := m.r.Run(ctx, nil, io.Discard, io.Discard, "daemon", "start"); err != nil {
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
	}
	if ssh := sshCommandFor(s.LimaSSHConfig); ssh != "" {
		args = append(args, "--ssh-command", ssh)
	}
	args = append(args, s.HostPath, s.LimaSSHHost+":"+s.VMPath)
	return m.r.Run(ctx, nil, io.Discard, io.Discard, args...)
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
	if s.VMUser == "" {
		return fmt.Errorf("VMUser is required for transcript path construction")
	}
	for _, sub := range subs {
		hostPath := path.Join(s.HomeDir, ".claude", sub)
		vmPath := path.Join("/home", s.VMUser, ".claude", sub)
		args := []string{
			"sync", "create",
			"--name=sandbox-" + s.VMID + "-transcripts-" + sub,
			"--label", sessionLabel(s.VMID),
			"--mode=one-way-safe",
		}
		if ssh := sshCommandFor(s.LimaSSHConfig); ssh != "" {
			args = append(args, "--ssh-command", ssh)
		}
		args = append(args, s.LimaSSHHost+":"+vmPath, hostPath)
		if err := m.r.Run(ctx, nil, io.Discard, io.Discard, args...); err != nil {
			return err
		}
	}
	return nil
}

type Session struct {
	Name   string `json:"name"`
	Status string `json:"status"`
}

func (m *Manager) SessionsFor(ctx context.Context, vmID string) ([]Session, error) {
	out, err := m.r.Output(ctx, nil,
		"sync", "list",
		"--label-selector="+sessionLabel(vmID),
		"--json",
	)
	if err != nil {
		return nil, err
	}
	if len(strings.TrimSpace(string(out))) == 0 {
		return nil, nil
	}
	var sessions []Session
	if err := json.Unmarshal(out, &sessions); err != nil {
		return nil, fmt.Errorf("parse mutagen json: %w", err)
	}
	return sessions, nil
}

func (m *Manager) PauseAll(ctx context.Context, vmID string) error {
	return m.r.Run(ctx, nil, io.Discard, io.Discard,
		"sync", "pause", "--label-selector="+sessionLabel(vmID))
}

func (m *Manager) ResumeAll(ctx context.Context, vmID string) error {
	return m.r.Run(ctx, nil, io.Discard, io.Discard,
		"sync", "resume", "--label-selector="+sessionLabel(vmID))
}

func (m *Manager) TerminateAll(ctx context.Context, vmID string) error {
	err := m.r.Run(ctx, nil, io.Discard, io.Discard,
		"sync", "terminate", "--label-selector="+sessionLabel(vmID))
	if err != nil && strings.Contains(err.Error(), "not found") {
		return nil
	}
	return err
}
