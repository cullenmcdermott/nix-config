// Package agents exposes the AGENTS.md content seeded into the sandbox VM.
package agents

import _ "embed"

//go:embed agents.md
var content string

// MarkdownContent returns the AGENTS.md content used to seed /etc/sandbox/AGENTS.md
// inside the VM. The content comes from the system's ompAgentsMd configuration.
func MarkdownContent() string { return content }
