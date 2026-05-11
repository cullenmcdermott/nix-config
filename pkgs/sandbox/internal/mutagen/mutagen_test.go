package mutagen

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"
)

type stubRunner struct {
	calls   [][]string
	outputs map[string]string
	err     error
}

func (s *stubRunner) Output(_ context.Context, _ io.Reader, args ...string) ([]byte, error) {
	s.calls = append(s.calls, args)
	if s.err != nil {
		return nil, s.err
	}
	if v, ok := s.outputs[strings.Join(args, " ")]; ok {
		return []byte(v), nil
	}
	return nil, nil
}

func (s *stubRunner) Run(_ context.Context, _ io.Reader, _, _ io.Writer, args ...string) error {
	s.calls = append(s.calls, args)
	return s.err
}

func TestCreateProjectSession_Args(t *testing.T) {
	r := &stubRunner{}
	m := New(r)
	err := m.CreateProject(context.Background(), Spec{
		VMID:        "demo-abcdef",
		HostPath:    "/Users/alice/proj",
		VMPath:      "/Users/alice/proj",
		LimaSSHHost: "lima-sandbox-demo-abcdef",
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(r.calls) != 1 {
		t.Fatalf("expected 1 call, got %v", r.calls)
	}
	args := r.calls[0]
	joined := strings.Join(args, " ")
	for _, must := range []string{
		"sync", "create",
		"--name=sandbox-demo-abcdef-project",
		"--mode=two-way-resolved",
		"/Users/alice/proj",
		"lima-sandbox-demo-abcdef:/Users/alice/proj",
	} {
		if !strings.Contains(joined, must) {
			t.Errorf("missing %q in: %s", must, joined)
		}
	}
}

func TestCreateTranscriptsSession_Args(t *testing.T) {
	r := &stubRunner{}
	m := New(r)
	err := m.CreateTranscripts(context.Background(), Spec{
		VMID:        "demo-abcdef",
		HomeDir:     "/Users/alice",
		LimaSSHHost: "lima-sandbox-demo-abcdef",
		VMUser:      "alice",
	}, TranscriptSubs)
	if err != nil {
		t.Fatal(err)
	}
	if len(r.calls) != 2 {
		t.Fatalf("expected 2 calls (projects + todos), got %v", r.calls)
	}
	for _, c := range r.calls {
		j := strings.Join(c, " ")
		if !strings.Contains(j, "--mode=one-way-safe") {
			t.Errorf("transcripts must be one-way: %s", j)
		}
	}
}

// NEW-I-2: when only one transcript sub is missing, only that one is created.
func TestCreateTranscripts_OnlyCreatesNamedSubs(t *testing.T) {
	r := &stubRunner{}
	m := New(r)
	err := m.CreateTranscripts(context.Background(), Spec{
		VMID:        "demo-abcdef",
		HomeDir:     "/Users/alice",
		LimaSSHHost: "lima-sandbox-demo-abcdef",
		VMUser:      "alice",
	}, []string{"projects"})
	if err != nil {
		t.Fatal(err)
	}
	if len(r.calls) != 1 {
		t.Fatalf("expected 1 call, got %v", r.calls)
	}
	joined := strings.Join(r.calls[0], " ")
	if !strings.Contains(joined, "transcripts-projects") {
		t.Errorf("expected projects session, got: %s", joined)
	}
	if strings.Contains(joined, "transcripts-todos") {
		t.Errorf("must not create todos when only projects requested: %s", joined)
	}
}

// Empty subs list is a no-op (nothing to reconcile).
func TestCreateTranscripts_EmptySubsIsNoop(t *testing.T) {
	r := &stubRunner{}
	m := New(r)
	err := m.CreateTranscripts(context.Background(), Spec{
		VMID:        "demo-abcdef",
		HomeDir:     "/Users/alice",
		LimaSSHHost: "lima-sandbox-demo-abcdef",
		VMUser:      "alice",
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(r.calls) != 0 {
		t.Fatalf("expected no calls for empty subs, got %v", r.calls)
	}
}

func TestStatus_ParsesJSON(t *testing.T) {
	r := &stubRunner{outputs: map[string]string{
		"sync list --label-selector=sandbox-vm-id=demo-abcdef --json": `[{"name":"sandbox-demo-abcdef-project","status":"watching"}]`,
	}}
	m := New(r)
	got, err := m.SessionsFor(context.Background(), "demo-abcdef")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0].Name != "sandbox-demo-abcdef-project" || got[0].Status != "watching" {
		t.Errorf("got %+v", got)
	}
}

func TestTerminate_Idempotent(t *testing.T) {
	r := &stubRunner{err: errors.New(`session "x" not found`)}
	m := New(r)
	if err := m.TerminateAll(context.Background(), "demo-abcdef"); err != nil {
		t.Fatalf("terminate must swallow not-found errors, got %v", err)
	}
}

func TestSessionsFor_EmptyResponse(t *testing.T) {
	r := &stubRunner{outputs: map[string]string{
		"sync list --label-selector=sandbox-vm-id=demo-abcdef --json": "",
	}}
	m := New(r)
	got, err := m.SessionsFor(context.Background(), "demo-abcdef")
	if err != nil {
		t.Fatal(err)
	}
	if got != nil {
		t.Errorf("expected nil for empty response, got %+v", got)
	}
}

// E-I-4: EnsureDaemon issues `mutagen daemon start`.
func TestEnsureDaemon_RunsDaemonStart(t *testing.T) {
	r := &stubRunner{}
	m := New(r)
	if err := m.EnsureDaemon(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(r.calls) != 1 {
		t.Fatalf("expected 1 call, got %v", r.calls)
	}
	joined := strings.Join(r.calls[0], " ")
	if joined != "daemon start" {
		t.Errorf("expected `daemon start`, got %q", joined)
	}
}

func TestLabelFiltering(t *testing.T) {
	r := &stubRunner{}
	m := New(r)
	_ = m.PauseAll(context.Background(), "my-vm-123abc")
	if len(r.calls) != 1 {
		t.Fatalf("expected 1 call, got %v", r.calls)
	}
	joined := strings.Join(r.calls[0], " ")
	if !strings.Contains(joined, "--label-selector=sandbox-vm-id=my-vm-123abc") {
		t.Errorf("missing label selector: %s", joined)
	}
}
