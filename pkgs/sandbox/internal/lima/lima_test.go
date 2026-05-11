package lima

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

type stubRunner struct {
	outputs map[string]string
	calls   [][]string
	err     error
}

func (s *stubRunner) Output(_ context.Context, _ io.Reader, args ...string) ([]byte, error) {
	s.calls = append(s.calls, args)
	if s.err != nil {
		return nil, s.err
	}
	key := strings.Join(args, " ")
	if v, ok := s.outputs[key]; ok {
		return []byte(v), nil
	}
	return nil, nil
}

func (s *stubRunner) Run(_ context.Context, _ io.Reader, _, _ io.Writer, args ...string) error {
	s.calls = append(s.calls, args)
	return s.err
}

func newTestBackend(t *testing.T, sr *stubRunner) *Backend {
	t.Helper()
	dir := t.TempDir()
	return New(sr, filepath.Join(dir, "vms-config"))
}

func TestBackend_Create_WritesYAMLAndCallsLimactlStart(t *testing.T) {
	sr := &stubRunner{}
	b := newTestBackend(t, sr)
	spec := backend.VMSpec{
		ID:        "demo-abcdef",
		CPUs:      2,
		MemoryMiB: 4096,
		DiskGiB:   30,
		Arch:      "aarch64",
	}
	if err := b.Create(context.Background(), spec); err != nil {
		t.Fatal(err)
	}
	yamlPath := filepath.Join(b.configRoot, "demo-abcdef", "lima.yaml")
	if _, err := os.Stat(yamlPath); err != nil {
		t.Fatalf("yaml not written: %v", err)
	}
	if len(sr.calls) == 0 {
		t.Fatal("expected at least one limactl invocation")
	}
	first := strings.Join(sr.calls[0], " ")
	if !strings.Contains(first, "start") || !strings.Contains(first, "--name=sandbox-demo-abcdef") {
		t.Fatalf("first limactl call was %q, want contain start + --name=sandbox-demo-abcdef", first)
	}
}

func TestBackend_Status_ParsesJSON(t *testing.T) {
	sr := &stubRunner{outputs: map[string]string{
		"list --json": `{"name":"sandbox-demo-abcdef","status":"Running"}` + "\n" +
			`{"name":"sandbox-other-aaaaaa","status":"Stopped"}` + "\n",
	}}
	b := newTestBackend(t, sr)
	st, err := b.Status(context.Background(), "demo-abcdef")
	if err != nil {
		t.Fatal(err)
	}
	if st != backend.StatusRunning {
		t.Errorf("got %s, want %s", st, backend.StatusRunning)
	}
}

func TestBackend_Status_GoneForUnknownVM(t *testing.T) {
	sr := &stubRunner{outputs: map[string]string{
		"list --json": ``,
	}}
	b := newTestBackend(t, sr)
	st, err := b.Status(context.Background(), "missing-zzzzzz")
	if err != nil {
		t.Fatal(err)
	}
	if st != backend.StatusGone {
		t.Errorf("got %s, want %s", st, backend.StatusGone)
	}
}

func TestBackend_Start_Stop_Destroy(t *testing.T) {
	sr := &stubRunner{}
	b := newTestBackend(t, sr)
	ctx := context.Background()
	if err := b.Start(ctx, "demo-abcdef"); err != nil {
		t.Fatal(err)
	}
	if err := b.Stop(ctx, "demo-abcdef"); err != nil {
		t.Fatal(err)
	}
	if err := b.Destroy(ctx, "demo-abcdef"); err != nil {
		t.Fatal(err)
	}
	want := [][]string{
		{"start", "--tty=false", "sandbox-demo-abcdef"},
		{"stop", "sandbox-demo-abcdef"},
		{"delete", "--force", "sandbox-demo-abcdef"},
	}
	for i, w := range want {
		got := sr.calls[i]
		if strings.Join(got, " ") != strings.Join(w, " ") {
			t.Errorf("call %d = %v, want %v", i, got, w)
		}
	}
}

func TestBackend_SSHConfig_PointsAtLimaDir(t *testing.T) {
	t.Setenv("HOME", "/Users/alice")
	sr := &stubRunner{}
	b := newTestBackend(t, sr)
	ssh, err := b.SSHConfig(context.Background(), "demo-abcdef")
	if err != nil {
		t.Fatal(err)
	}
	want := "/Users/alice/.lima/sandbox-demo-abcdef/ssh.config"
	if ssh.ConfigFile != want {
		t.Errorf("ConfigFile = %q, want %q", ssh.ConfigFile, want)
	}
	if ssh.Host != "lima-sandbox-demo-abcdef" {
		t.Errorf("Host = %q", ssh.Host)
	}
}

func TestBackend_PropagatesRunnerErrors(t *testing.T) {
	sr := &stubRunner{err: errors.New("boom")}
	b := newTestBackend(t, sr)
	err := b.Start(context.Background(), "demo-abcdef")
	if err == nil || !strings.Contains(err.Error(), "boom") {
		t.Fatalf("expected propagated error, got %v", err)
	}
}

// Compile-time assertion that *Backend satisfies the interface.
var _ backend.Backend = (*Backend)(nil)

// Silence unused-import warning when running individual tests.
var _ = bytes.NewBuffer
