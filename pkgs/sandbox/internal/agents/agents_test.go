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
		"## Environment",
		"## Verify Before Claiming",
		"## Available CLI Tools",
	} {
		if !strings.Contains(c, must) {
			t.Errorf("missing heading: %q", must)
		}
	}
}

func TestMarkdownContent_HasNixRules(t *testing.T) {
	c := MarkdownContent()
	if !strings.Contains(c, "nix-darwin") {
		t.Errorf("missing nix-darwin reference")
	}
	if !strings.Contains(c, "brew install") {
		t.Errorf("missing brew install warning")
	}
	if !strings.Contains(c, "ast-grep") {
		t.Errorf("missing ast-grep in available tools")
	}
}
