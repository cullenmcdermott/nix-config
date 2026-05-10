package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"github.com/cullenmcdermott/system-config/sandbox/internal/bridgeclient"
)

const (
	bridgeSocket = "/run/sandbox-bridge.sock"
	tokenPath    = "/etc/sandbox/bridge-token"
	realClaude   = "/usr/local/bin/claude.real"
)

func main() {
	tok, err := os.ReadFile(tokenPath)
	if err != nil {
		fail("read bridge token: %v", err)
	}
	c := bridgeclient.New(bridgeSocket, strings.TrimSpace(string(tok)))

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	auth, err := c.Auth(ctx)
	if err != nil {
		fail("fetch claude auth: %v", err)
	}

	if err := os.Setenv("ANTHROPIC_API_KEY", auth.Token); err != nil {
		fail("set env: %v", err)
	}

	if _, err := exec.LookPath(realClaude); err != nil {
		fail("real claude not found at %s: %v", realClaude, err)
	}
	args := append([]string{realClaude}, os.Args[1:]...)
	if err := syscall.Exec(realClaude, args, os.Environ()); err != nil {
		fail("exec: %v", err)
	}
}

func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "sandbox-claude: "+format+"\n", a...)
	os.Exit(1)
}
