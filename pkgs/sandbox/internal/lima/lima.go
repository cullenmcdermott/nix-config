package lima

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

// Backend is a Lima-driven backend.Backend implementation.
type Backend struct {
	runner     Runner
	configRoot string // ~/.config/sandbox/vms (callers pass the full path)
}

// New returns a Backend that writes per-VM lima.yaml files under configRoot
// and shells out via runner.
func New(r Runner, configRoot string) *Backend {
	return &Backend{runner: r, configRoot: configRoot}
}

func instanceName(id backend.VMID) string { return "sandbox-" + string(id) }

func (b *Backend) Create(ctx context.Context, s backend.VMSpec) error {
	yaml, err := RenderTemplate(s)
	if err != nil {
		return err
	}
	dir := filepath.Join(b.configRoot, string(s.ID))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	yamlPath := filepath.Join(dir, "lima.yaml")
	if err := os.WriteFile(yamlPath, []byte(yaml), 0o644); err != nil {
		return err
	}
	return b.runner.Run(ctx, nil, os.Stdout, os.Stderr,
		"start",
		"--name="+instanceName(s.ID),
		"--tty=false",
		yamlPath,
	)
}

func (b *Backend) Start(ctx context.Context, id backend.VMID) error {
	return b.runner.Run(ctx, nil, os.Stdout, os.Stderr, "start", instanceName(id))
}

func (b *Backend) Stop(ctx context.Context, id backend.VMID) error {
	return b.runner.Run(ctx, nil, os.Stdout, os.Stderr, "stop", instanceName(id))
}

func (b *Backend) Destroy(ctx context.Context, id backend.VMID) error {
	return b.runner.Run(ctx, nil, os.Stdout, os.Stderr, "delete", "--force", instanceName(id))
}

type limaListEntry struct {
	Name   string `json:"name"`
	Status string `json:"status"`
}

func (b *Backend) listEntries(ctx context.Context) ([]limaListEntry, error) {
	out, err := b.runner.Output(ctx, nil, "list", "--json")
	if err != nil {
		return nil, err
	}
	var entries []limaListEntry
	scanner := bufio.NewScanner(bytes.NewReader(out))
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var e limaListEntry
		if err := json.Unmarshal(line, &e); err != nil {
			return nil, fmt.Errorf("parse limactl list line %q: %w", line, err)
		}
		entries = append(entries, e)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return entries, nil
}

func (b *Backend) Status(ctx context.Context, id backend.VMID) (backend.Status, error) {
	entries, err := b.listEntries(ctx)
	if err != nil {
		return backend.StatusUnknown, err
	}
	want := instanceName(id)
	for _, e := range entries {
		if e.Name == want {
			return mapLimaStatus(e.Status), nil
		}
	}
	return backend.StatusGone, nil
}

func (b *Backend) SSHConfig(_ context.Context, id backend.VMID) (backend.SSHConfig, error) {
	home := os.Getenv("HOME")
	if home == "" {
		return backend.SSHConfig{}, fmt.Errorf("HOME unset")
	}
	return backend.SSHConfig{
		ConfigFile: filepath.Join(home, ".lima", instanceName(id), "ssh.config"),
		Host:       "lima-" + instanceName(id),
	}, nil
}

func (b *Backend) List(ctx context.Context) ([]backend.VMInfo, error) {
	entries, err := b.listEntries(ctx)
	if err != nil {
		return nil, err
	}
	var out []backend.VMInfo
	for _, e := range entries {
		if !strings.HasPrefix(e.Name, "sandbox-") {
			continue
		}
		id := backend.VMID(strings.TrimPrefix(e.Name, "sandbox-"))
		out = append(out, backend.VMInfo{ID: id, Status: mapLimaStatus(e.Status)})
	}
	return out, nil
}

func mapLimaStatus(s string) backend.Status {
	switch strings.ToLower(s) {
	case "running":
		return backend.StatusRunning
	case "stopped":
		return backend.StatusStopped
	case "":
		return backend.StatusGone
	default:
		return backend.StatusUnknown
	}
}
