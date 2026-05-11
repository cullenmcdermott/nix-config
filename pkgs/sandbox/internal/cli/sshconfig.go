package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// sshIncludeLine is the Include directive added to ~/.ssh/config so that
// the system SSH (used by mutagen) can resolve Lima's per-VM host aliases
// (e.g. lima-sandbox-<id>). Lima writes an SSH config per instance at
// ~/.lima/<instance>/ssh.config; the glob covers all sandbox VMs.
const sshIncludeLine = "Include ~/.lima/sandbox-*/ssh.config"

// ensureSSHConfigInclude ensures that ~/.ssh/config contains the Include
// directive for sandbox Lima VM SSH configs. This is idempotent: if the
// line already exists, it is a no-op. If ~/.ssh or ~/.ssh/config do not
// exist, they are created.
func ensureSSHConfigInclude(home string) error {
	sshDir := filepath.Join(home, ".ssh")
	sshConfig := filepath.Join(sshDir, "config")

	data, err := os.ReadFile(sshConfig)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("read %s: %w", sshConfig, err)
	}

	content := string(data)

	// Already present — nothing to do.
	if strings.Contains(content, sshIncludeLine) {
		return nil
	}

	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		return fmt.Errorf("create %s: %w", sshDir, err)
	}

	// Prepend: Include directives must appear before Host blocks.
	newContent := sshIncludeLine + "\n"
	if content != "" {
		newContent += "\n" + content
	}

	if err := os.WriteFile(sshConfig, []byte(newContent), 0o600); err != nil {
		return fmt.Errorf("write %s: %w", sshConfig, err)
	}

	return nil
}
