package agents

import (
	"strings"
	"testing"
)

func TestMarkdownContent_NotEmpty(t *testing.T) {
	if c := MarkdownContent(); len(c) < 200 {
		t.Fatalf("content suspiciously short: %d chars", len(c))
	}
}

func TestMarkdownContent_HasExpectedHeadings(t *testing.T) {
	c := MarkdownContent()
	for _, must := range []string{
		"## Sandbox Environment",
		"### Package Management",
		"### Bridge to Host",
		"### Verify Before Claiming",
	} {
		if !strings.Contains(c, must) {
			t.Errorf("missing heading: %q", must)
		}
	}
}

func TestMarkdownContent_HasFloxRules(t *testing.T) {
	c := MarkdownContent()
	if !strings.Contains(c, "flox install") {
		t.Errorf("missing flox install reference")
	}
	if !strings.Contains(c, "nix run") {
		t.Errorf("missing nix run reference")
	}
}
func TestOmpMarkdownContent_NotEmpty(t *testing.T) {
	if OmpMarkdownContent() == "" {
		t.Fatal("OmpMarkdownContent() returned empty string")
	}
}

func TestOmpMarkdownContent_HasExpectedHeadings(t *testing.T) {
	content := OmpMarkdownContent()
	for _, heading := range []string{
		"## Sandbox Environment",
		"### Package Management",
		"### Bridge to Host",
		"### Key Paths",
		"### Known Gaps",
	} {
		if !strings.Contains(content, heading) {
			t.Errorf("missing heading %q", heading)
		}
	}
}

func TestOmpMarkdownContent_HasOmpSpecificContent(t *testing.T) {
	content := OmpMarkdownContent()
	for _, needle := range []string{
		"PI_CODING_AGENT_DIR",
		"PI_CONFIG_DIR",
		"~/.config/omp/agent/",
	} {
		if !strings.Contains(content, needle) {
			t.Errorf("missing omp-specific content %q", needle)
		}
	}
}
