// Package lima implements the v1 Backend using Lima (limactl).
package lima

import (
	"bytes"
	"fmt"
	"strings"

	"github.com/cullenmcdermott/system-config/sandbox/internal/backend"
)

// Image SHA-256 digests track the same Ubuntu 24.04 minimal cloud images
// that pomp uses today (modules/home-manager/pomp.nix). Bump when the
// upstream image is republished.
type imageRef struct {
	URL    string
	Digest string
	Arch   string
}

var images = map[string]imageRef{
	"aarch64": {
		URL:    "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-arm64.img",
		Digest: "sha256:0cc0a529a52109b52bf697a0d90bdd0f252e7ad91b3a67f70879d56d1f64e240",
		Arch:   "aarch64",
	},
	"x86_64": {
		URL:    "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img",
		Digest: "sha256:7cbfa215a3774c46c6dc29b457f4e9667acda85fc04c7971e1e592b5056e7573",
		Arch:   "x86_64",
	},
}

// RenderTemplate produces a lima.yaml for the given spec.
func RenderTemplate(s backend.VMSpec) (string, error) {
	img, ok := images[s.Arch]
	if !ok {
		return "", fmt.Errorf("unsupported arch %q (want aarch64 or x86_64)", s.Arch)
	}

	memGiB := s.MemoryMiB / 1024
	if s.MemoryMiB%1024 != 0 {
		memGiB++
	}

	var b bytes.Buffer
	fmt.Fprintln(&b, "vmType: vz")
	fmt.Fprintf(&b, "cpus: %d\n", s.CPUs)
	fmt.Fprintf(&b, "memory: %dGiB\n", memGiB)
	fmt.Fprintf(&b, "disk: %dGiB\n", s.DiskGiB)
	fmt.Fprintln(&b)
	fmt.Fprintln(&b, "images:")
	fmt.Fprintf(&b, "  - location: %q\n", img.URL)
	fmt.Fprintf(&b, "    arch: %s\n", img.Arch)
	fmt.Fprintf(&b, "    digest: %q\n", img.Digest)
	fmt.Fprintln(&b)

	// Mounts — filter out Mutagen-managed mounts (those are handled by the
	// Mutagen daemon instead). Virtiofs mounts (claude RO subpaths, extra
	// user mounts) appear in the Lima config.
	var virtiofsMounts []backend.Mount
	for _, m := range s.Mounts {
		if m.SyncMode != backend.SyncMutagen {
			virtiofsMounts = append(virtiofsMounts, m)
		}
	}
	if len(virtiofsMounts) > 0 {
		fmt.Fprintln(&b, "mounts:")
		for _, m := range virtiofsMounts {
			writable := false
			if m.Writable {
				writable = true
			}
			fmt.Fprintf(&b, "  - location: %q\n", m.HostPath)
			fmt.Fprintf(&b, "    mountPoint: %q\n", m.VMPath)
			fmt.Fprintf(&b, "    writable: %t\n", writable)
		}
		fmt.Fprintln(&b)
		fmt.Fprintln(&b, "mountType: virtiofs")
		fmt.Fprintln(&b)
	}

	// Provision script — run on first boot as one entry so multi-line scripts
	// (heredocs, if/fi, set -euo pipefail, etc.) execute in a single shell.
	if s.Provision.Script != "" {
		fmt.Fprintln(&b, "provision:")
		fmt.Fprintln(&b, "  - mode: system")
		fmt.Fprintln(&b, "    script: |")
		for _, line := range strings.Split(s.Provision.Script, "\n") {
			fmt.Fprintf(&b, "      %s\n", line)
		}
	}

	fmt.Fprintln(&b, "ssh: {}")
	return b.String(), nil
}
