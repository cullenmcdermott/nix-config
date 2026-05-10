package cli

import (
	"strings"
	"testing"
)

func TestArchToPlatform(t *testing.T) {
	cases := []struct {
		arch string
		want string
	}{
		{"aarch64", "linux-arm64"},
		{"x86_64", "linux-x64"},
		{"", "linux-arm64"}, // unknown falls back to linux-arm64
	}
	for _, tc := range cases {
		got := archToPlatform(tc.arch)
		if got != tc.want {
			t.Errorf("archToPlatform(%q) = %q, want %q", tc.arch, got, tc.want)
		}
	}
}

func TestBuildClaudeURL(t *testing.T) {
	platforms := []string{"linux-arm64", "linux-x64", "darwin-arm64", "darwin-x64"}
	for _, platform := range platforms {
		url := BuildClaudeURL("2.1.138", platform)
		// Must contain the platform exactly once.
		if count := strings.Count(url, platform); count != 1 {
			t.Errorf("BuildClaudeURL(%q) contains platform %q %d times, want 1: %s", platform, platform, count, url)
		}
		// Must not double-prefix linux-.
		if strings.Contains(url, "linux-linux-") {
			t.Errorf("BuildClaudeURL(%q) has double linux- prefix: %s", platform, url)
		}
		if strings.Contains(url, "linux-darwin-") {
			t.Errorf("BuildClaudeURL(%q) has linux-darwin- prefix: %s", platform, url)
		}
	}
}
