// Command sandbox-xdg-open is the in-VM shim installed as /usr/local/bin/xdg-open.
//
// It accepts exactly one http(s) URL and forwards it to the macOS host via the
// sandbox bridge, which uses `open` to launch the host browser.
package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/cullenmcdermott/system-config/sandbox/internal/bridgeclient"
)

const (
	socketPath = "/run/sandbox/bridge.sock"
	tokenPath  = "/etc/sandbox/bridge-token"

	bridgeHint = "sandbox bridge is only available in sessions started via `sandbox claude` / `sandbox shell`"
)

func main() {
	url, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(2)
	}

	token, err := readToken(tokenPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "sandbox xdg-open shim: read bridge token: %v\nhint: %s\n", err, bridgeHint)
		os.Exit(1)
	}

	if _, err := os.Stat(socketPath); err != nil {
		fmt.Fprintf(os.Stderr, "sandbox xdg-open shim: bridge socket %s unavailable: %v\nhint: %s\n", socketPath, err, bridgeHint)
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	c := bridgeclient.New(socketPath, token)
	if err := c.OpenURL(ctx, url); err != nil {
		fmt.Fprintf(os.Stderr, "sandbox xdg-open shim: %v\n", err)
		os.Exit(1)
	}
}

func readToken(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	tok := strings.TrimSpace(string(b))
	if tok == "" {
		return "", fmt.Errorf("token file %s is empty", path)
	}
	return tok, nil
}
