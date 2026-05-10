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
	VMID        string // e.g. "demo-abcdef"
	HostPath    string // host-side absolute path (project sync only)
	VMPath      string // VM-side absolute path (project sync only)
	HomeDir     string // host home, used for transcripts (e.g. "/Users/alice")
	LimaSSHHost string // ssh alias from lima.SSHConfig.Host
}

func sessionLabel(vmID string) string { return "sandbox-vm-id=" + vmID }

func (m *Manager) CreateProject(ctx context.Context, s Spec) error {
	args := []string{
		"sync", "create",
		"--name=sandbox-" + s.VMID + "-project",
		"--label", sessionLabel(s.VMID),
		"--mode=two-way-resolved",
		"--ignore-vcs",
		s.HostPath,
		s.LimaSSHHost + ":" + s.VMPath,
	}
	return m.r.Run(ctx, nil, io.Discard, io.Discard, args...)
}

func (m *Manager) CreateTranscripts(ctx context.Context, s Spec) error {
	vmUser := currentUserGuess(s.HomeDir)
	for _, sub := range []string{"projects", "todos"} {
		hostPath := path.Join(s.HomeDir, ".claude", sub)
		vmPath := path.Join("/home", vmUser, ".claude", sub)
		args := []string{
			"sync", "create",
			"--name=sandbox-" + s.VMID + "-transcripts-" + sub,
			"--label", sessionLabel(s.VMID),
			"--mode=one-way-safe",
			s.LimaSSHHost + ":" + vmPath,
			hostPath,
		}
		if err := m.r.Run(ctx, nil, io.Discard, io.Discard, args...); err != nil {
			return err
		}
	}
	return nil
}

func currentUserGuess(homeDir string) string {
	// "/Users/alice" -> "alice"
	parts := strings.Split(strings.Trim(homeDir, "/"), "/")
	return parts[len(parts)-1]
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