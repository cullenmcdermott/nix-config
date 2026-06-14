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

func TestClaudeGCSBase(t *testing.T) {
	base := ClaudeGCSBase()
	if !strings.HasPrefix(base, "https://storage.googleapis.com/claude-code-dist-") {
		t.Errorf("unexpected base URL: %s", base)
	}
	if !strings.HasSuffix(base, "/claude-code-releases") {
		t.Errorf("base must end in /claude-code-releases (no trailing slash): %s", base)
	}
	if !strings.Contains(base, ClaudeGCSBucket) {
		t.Errorf("base missing bucket id: %s", base)
	}
}

func TestClaudeChannelIsValid(t *testing.T) {
	if ClaudeChannel != "stable" && ClaudeChannel != "latest" {
		t.Errorf("ClaudeChannel must be stable or latest, got %q", ClaudeChannel)
	}
}
