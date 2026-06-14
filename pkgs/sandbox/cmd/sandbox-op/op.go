package main

import (
	"errors"
	"strings"
)

// usageMsg is the single-line error printed when the args don't match the only
// supported invocation: `op read op://<vault>/<item>/<field>`.
const usageMsg = "sandbox op shim: only 'op read op://<vault>/<item>/<field>' is supported (reads are forwarded to the host via the sandbox bridge)"

// parseArgs validates argv[1:] for the op shim. It returns the op:// ref on
// success, or a descriptive error otherwise.
//
// Accepted shape: exactly two arguments, "read" followed by an op:// ref.
// Anything else (no args, --version, --help, "item get", "signin", extra
// arguments, non-op:// ref) is rejected with the same usage message — we don't
// want the shim to silently swallow flags or accept partial forms that a user
// might assume work.
func parseArgs(args []string) (string, error) {
	if len(args) != 2 {
		return "", errors.New(usageMsg)
	}
	if args[0] != "read" {
		return "", errors.New(usageMsg)
	}
	ref := args[1]
	if !strings.HasPrefix(ref, "op://") {
		return "", errors.New(usageMsg)
	}
	return ref, nil
}
