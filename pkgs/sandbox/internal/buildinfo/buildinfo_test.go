package buildinfo

import "testing"

func TestVersion_DefaultIsDev(t *testing.T) {
	got := Version()
	if got != "dev" {
		t.Fatalf("Version() = %q, want %q", got, "dev")
	}
}

func TestVersion_OverridableViaLdflags(t *testing.T) {
	// The exported `version` package var is the one ldflags sets at link time.
	// Simulate that by writing it in this test.
	old := version
	defer func() { version = old }()
	version = "1.2.3"
	if got := Version(); got != "1.2.3" {
		t.Fatalf("Version() = %q, want %q", got, "1.2.3")
	}
}