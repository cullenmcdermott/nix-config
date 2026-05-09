package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println("sandbox dev")
		return
	}
	fmt.Fprintln(os.Stderr, "sandbox: no subcommand wired yet (Phase 0 scaffolding)")
	os.Exit(2)
}