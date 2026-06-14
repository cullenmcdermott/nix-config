package main

import (
	"strings"
	"testing"
)

func TestParseArgs_ValidHTTP(t *testing.T) {
	got, err := parseArgs([]string{"http://example.com/path?q=1"})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if got != "http://example.com/path?q=1" {
		t.Errorf("got %q", got)
	}
}

func TestParseArgs_ValidHTTPS(t *testing.T) {
	got, err := parseArgs([]string{"https://anthropic.com/login"})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if got != "https://anthropic.com/login" {
		t.Errorf("got %q", got)
	}
}

func TestParseArgs_RejectsNonHTTPSchemes(t *testing.T) {
	cases := []string{
		"file:///etc/passwd",
		"ssh://host",
		"javascript:alert(1)",
		"data:text/plain,hi",
		"ftp://example.com",
		"mailto:me@example.com",
	}
	for _, raw := range cases {
		_, err := parseArgs([]string{raw})
		if err == nil {
			t.Errorf("expected error for %q", raw)
			continue
		}
		if !strings.Contains(err.Error(), "http(s)") {
			t.Errorf("error for %q missing hint: %v", raw, err)
		}
	}
}

func TestParseArgs_RejectsBareString(t *testing.T) {
	_, err := parseArgs([]string{"example.com"})
	if err == nil {
		t.Fatal("expected error for schemeless URL")
	}
}

func TestParseArgs_RejectsEmptyHost(t *testing.T) {
	_, err := parseArgs([]string{"https:///path"})
	if err == nil {
		t.Fatal("expected error for empty host")
	}
}

func TestParseArgs_RejectsNoArgs(t *testing.T) {
	_, err := parseArgs(nil)
	if err == nil {
		t.Fatal("expected error for no args")
	}
}

func TestParseArgs_RejectsMultipleArgs(t *testing.T) {
	_, err := parseArgs([]string{"https://a.example.com", "https://b.example.com"})
	if err == nil {
		t.Fatal("expected error for two args")
	}
}

func TestParseArgs_RejectsControlChars(t *testing.T) {
	// net/url rejects URLs containing newlines / control bytes.
	_, err := parseArgs([]string{"https://example.com/\x00"})
	if err == nil {
		t.Fatal("expected error for control char in URL")
	}
}
