// Package buildinfo exposes build-time metadata.
// version is overwritten at link time via:
//
//	go build -ldflags "-X github.com/.../internal/buildinfo.version=<v>" ./cmd/sandbox
package buildinfo

var version = "dev"

func Version() string { return version }
