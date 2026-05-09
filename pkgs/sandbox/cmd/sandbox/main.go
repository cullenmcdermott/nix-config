package main

import (
	"fmt"
	"os"

	"github.com/cullenmcdermott/system-config/sandbox/internal/cli"
)

func main() {
	if err := cli.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "sandbox:", err)
		os.Exit(1)
	}
}