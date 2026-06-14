package main

import (
	"strings"
	"testing"
)

func TestParseArgs_ValidRead(t *testing.T) {
	ref, err := parseArgs([]string{"read", "op://Private/GitHub/token"})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if ref != "op://Private/GitHub/token" {
		t.Errorf("ref = %q, want op://Private/GitHub/token", ref)
	}
}

func TestParseArgs_RejectsWrongSubcommand(t *testing.T) {
	cases := [][]string{
		{"item", "get", "GitHub"},
		{"signin"},
		{"write", "op://Private/X/y", "value"},
		{"list"},
	}
	for _, args := range cases {
		_, err := parseArgs(args)
		if err == nil {
			t.Errorf("expected error for args %v", args)
			continue
		}
		if !strings.Contains(err.Error(), "only 'op read") {
			t.Errorf("error for %v missing usage hint: %v", args, err)
		}
	}
}

func TestParseArgs_RejectsMissingRef(t *testing.T) {
	_, err := parseArgs([]string{"read"})
	if err == nil {
		t.Fatal("expected error for missing ref")
	}
}

func TestParseArgs_RejectsNoArgs(t *testing.T) {
	_, err := parseArgs(nil)
	if err == nil {
		t.Fatal("expected error for no args")
	}
	_, err = parseArgs([]string{})
	if err == nil {
		t.Fatal("expected error for empty args")
	}
}

func TestParseArgs_RejectsNonOpRef(t *testing.T) {
	cases := []string{
		"https://evil.com/secret",
		"file:///etc/passwd",
		"GitHub/token",
		"-rf",
		"--help",
	}
	for _, ref := range cases {
		_, err := parseArgs([]string{"read", ref})
		if err == nil {
			t.Errorf("expected error for ref %q", ref)
		}
	}
}

func TestParseArgs_RejectsExtraArgs(t *testing.T) {
	_, err := parseArgs([]string{"read", "op://Private/X/y", "extra"})
	if err == nil {
		t.Fatal("expected error for extra args")
	}
	_, err = parseArgs([]string{"read", "op://Private/X/y", "--field", "password"})
	if err == nil {
		t.Fatal("expected error for trailing flags")
	}
}

func TestParseArgs_RejectsVersionFlag(t *testing.T) {
	_, err := parseArgs([]string{"--version"})
	if err == nil {
		t.Fatal("expected error for --version")
	}
}
