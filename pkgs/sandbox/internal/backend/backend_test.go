package backend

import (
	"context"
	"testing"
)

func TestFake_RoundTripsLifecycle(t *testing.T) {
	ctx := context.Background()
	f := NewFake()
	spec := VMSpec{
		ID:        "myproj-abcdef",
		CPUs:      2,
		MemoryMiB: 4096,
		DiskGiB:   30,
		Arch:      "aarch64",
	}
	if err := f.Create(ctx, spec); err != nil {
		t.Fatal(err)
	}
	st, err := f.Status(ctx, spec.ID)
	if err != nil {
		t.Fatal(err)
	}
	if st != StatusStopped {
		t.Fatalf("after Create want STOPPED, got %s", st)
	}
	if err := f.Start(ctx, spec.ID); err != nil {
		t.Fatal(err)
	}
	st, _ = f.Status(ctx, spec.ID)
	if st != StatusRunning {
		t.Fatalf("after Start want RUNNING, got %s", st)
	}
	if err := f.Stop(ctx, spec.ID); err != nil {
		t.Fatal(err)
	}
	st, _ = f.Status(ctx, spec.ID)
	if st != StatusStopped {
		t.Fatalf("after Stop want STOPPED, got %s", st)
	}
	if err := f.Destroy(ctx, spec.ID); err != nil {
		t.Fatal(err)
	}
	st, _ = f.Status(ctx, spec.ID)
	if st != StatusGone {
		t.Fatalf("after Destroy want GONE, got %s", st)
	}
}

func TestFake_StatusForUnknown(t *testing.T) {
	st, err := NewFake().Status(context.Background(), "nope")
	if err != nil {
		t.Fatal(err)
	}
	if st != StatusGone {
		t.Fatalf("unknown id Status = %s, want GONE", st)
	}
}
