package main

import (
	"errors"
	"net/url"
)

// usageMsg is the single-line error printed when args are wrong.
const usageMsg = "sandbox xdg-open shim: only http(s) URLs can be opened on the host"

// parseArgs validates argv[1:] for the xdg-open shim. It requires exactly one
// argument that parses as a URL with scheme http or https and a non-empty host.
func parseArgs(args []string) (string, error) {
	if len(args) != 1 {
		return "", errors.New(usageMsg)
	}
	raw := args[0]
	u, err := url.Parse(raw)
	if err != nil {
		return "", errors.New(usageMsg)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", errors.New(usageMsg)
	}
	if u.Host == "" {
		return "", errors.New(usageMsg)
	}
	return raw, nil
}
