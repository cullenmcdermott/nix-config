// Package agents exposes the AGENTS.md content seeded into the sandbox VM.
package agents

import _ "embed"

//go:embed agents.md
var content string
//go:embed omp.md
var ompContent string

// MarkdownContent returns the AGENTS.md content used to seed /etc/sandbox/AGENTS.md
// inside the VM. The content comes from the system's ompAgentsMd configuration.
func MarkdownContent() string { return content }
// OmpMarkdownContent returns the AGENTS.md content written into
// ~/.config/omp/agent/AGENTS.md inside the VM.
func OmpMarkdownContent() string { return ompContent }
