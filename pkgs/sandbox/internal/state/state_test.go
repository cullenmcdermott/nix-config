package state

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRead_MissingFileReturnsNew(t *testing.T) {
	dir := t.TempDir()
	got, err := Read(filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	if got != StateNew {
		t.Fatalf("got %q, want %q", got, StateNew)
	}
}

func TestWriteRead_RoundTrip(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "state.json")
	for _, s := range []State{StateProvisioning, StateStopped, StateRunning, StateFailed, StateDestroying, StateDestroyFailed} {
		if err := Write(p, s); err != nil {
			t.Fatalf("write %s: %v", s, err)
		}
		got, err := Read(p)
		if err != nil {
			t.Fatalf("read %s: %v", s, err)
		}
		if got != s {
			t.Errorf("round-trip %s -> %s", s, got)
		}
	}
}

func TestClear(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "state.json")
	if err := Write(p, StateRunning); err != nil {
		t.Fatal(err)
	}
	if err := Clear(p); err != nil {
		t.Fatal(err)
	}
	got, err := Read(p)
	if err != nil {
		t.Fatal(err)
	}
	if got != StateNew {
		t.Fatalf("after Clear got %q, want %q", got, StateNew)
	}
}

func TestRecord_RoundTrip(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "s.json")
	want := Record{State: StateDestroyFailed, LastFailedStep: "bridge-stop"}
	if err := WriteRecord(p, want); err != nil {
		t.Fatal(err)
	}
	got, err := ReadRecord(p)
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Errorf("round-trip: %+v", got)
	}
}

func TestRead_BadFile(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "state.json")
	if err := os.WriteFile(p, []byte("not json"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Read(p); err == nil {
		t.Fatal("expected error reading malformed state file")
	}
}
