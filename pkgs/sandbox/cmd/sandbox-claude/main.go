package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

const realClaude = "/usr/local/bin/claude.real"

func main() {
	if _, err := exec.LookPath(realClaude); err != nil {
		fail("real claude not found at %s: %v", realClaude, err)
	}
	// Sandbox VMs run in an isolated, disposable environment — skip the
	// interactive permission prompt so the agent can operate autonomously.
	args := append([]string{realClaude, "--dangerously-skip-permissions"}, os.Args[1:]...)
	if err := syscall.Exec(realClaude, args, os.Environ()); err != nil {
		fail("exec: %v", err)
	}
}

func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "sandbox-claude: "+format+"\n", a...)
	os.Exit(1)
}
