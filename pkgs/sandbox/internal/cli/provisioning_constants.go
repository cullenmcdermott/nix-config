package cli

// Pinned versions and SHA-256 digests for runtime-installed components.
// Bump these together; the provision script fails closed on checksum mismatch.
const (
	// Flox: https://downloads.flox.dev/by-env/stable/deb/flox-<version>.aarch64-linux.deb
	FloxVersion = "1.12.1"
	FloxURL     = "https://downloads.flox.dev/by-env/stable/deb/flox-1.12.1.aarch64-linux.deb"
	// hex sha256 of the deb (sha256sum output).
	FloxSHA256 = "5a79f7e4f8a940ed5cb4df868fe9bb5a7eb46365498d985b698218023297b5b4"

	// Claude Code: standalone binary from Anthropic's GCS bucket. The VM
	// resolves the channel's current version at provision time (every boot)
	// and verifies the download against the sha256 in the release manifest
	// (<base>/<version>/manifest.json), same as the official installer.
	ClaudeGCSBucket = "86c565f3-f756-42ad-8dfa-d59b1c096819"
	// ClaudeChannel is the release channel VMs track: "stable" or "latest".
	ClaudeChannel = "latest"
	// omp (Oh My Pi): standalone binary from GitHub releases.
	// URL pattern: https://github.com/can1357/oh-my-pi/releases/download/v<version>/<platform>
	// Platform key: aarch64→omp-linux-arm64, x86_64→omp-linux-x64
	OmpVersion = "15.11.0"
	// hex sha256 of the linux-arm64 binary.
	OmpSHA256 = "c67a265c5d19d65fd506d8c4a56e1d29a363a3b98e3aa539ba7a61ad9bd5a850"
)

// ClaudeGCSBase returns the base URL for Claude Code releases. Version
// resolution and binary download paths are built from it inside the VM:
// <base>/<channel> → version, <base>/<version>/manifest.json → checksums,
// <base>/<version>/<platform>/claude → binary.
func ClaudeGCSBase() string {
	return "https://storage.googleapis.com/claude-code-dist-" + ClaudeGCSBucket + "/claude-code-releases"
}

// BuildOmpURL returns the GitHub releases URL for the omp binary.
func BuildOmpURL(version, arch string) string {
	platform := "omp-linux-arm64"
	if arch == "x86_64" {
		platform = "omp-linux-x64"
	}
	return "https://github.com/can1357/oh-my-pi/releases/download/v" + version + "/" + platform
}
