package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildOmpVMConfig_RewritesSessionDir(t *testing.T) {
	home := t.TempDir()
	configDir := filepath.Join(home, ".config", "omp", "agent")
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		t.Fatal(err)
	}
	configContent := "defaultModel: claude-sonnet-4-6\ndefaultProvider: github-copilot\nsessionDir: /Users/cullen/.local/state/omp/sessions\n"
	if err := os.WriteFile(filepath.Join(configDir, "config.yml"), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := buildOmpVMConfig(home)
	if !strings.Contains(got, "sessionDir:") {
		t.Errorf("missing sessionDir in output:\n%s", got)
	}
	if strings.Contains(got, "/Users/cullen") {
		t.Errorf("host path leaked into VM config:\n%s", got)
	}
	if !strings.Contains(got, ".local/state/omp/sessions") {
		t.Errorf("VM sessionDir not set correctly:\n%s", got)
	}
}

func TestBuildOmpVMConfig_MissingFile(t *testing.T) {
	home := t.TempDir()
	got := buildOmpVMConfig(home)
	if got != "" {
		t.Errorf("expected empty string for missing config, got:\n%s", got)
	}
}

func TestBuildOmpVMConfig_PreservesProviderConfig(t *testing.T) {
	home := t.TempDir()
	configDir := filepath.Join(home, ".config", "omp", "agent")
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		t.Fatal(err)
	}
	configContent := "defaultModel: claude-sonnet-4-6\ndefaultProvider: github-copilot\nenableSkillCommands: true\nsessionDir: /Users/cullen/.local/state/omp/sessions\n"
	if err := os.WriteFile(filepath.Join(configDir, "config.yml"), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := buildOmpVMConfig(home)
	if !strings.Contains(got, "defaultProvider:") || !strings.Contains(got, "github-copilot") {
		t.Errorf("provider config not preserved:\n%s", got)
	}
	if !strings.Contains(got, "enableSkillCommands:") {
		t.Errorf("enableSkillCommands not preserved:\n%s", got)
	}
}
