package cli

// Pinned versions and SHA-256 digests for runtime-installed components.
// Bump these together; the provision script fails closed on checksum mismatch.
const (
	// Flox: https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb
	FloxVersion = "1.12.0"
	FloxURL     = "https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb"
	// hex sha256, NOT nix-prefetch-url base32.
	// Computed via: nix hash convert --to base16 --hash-algo sha256 <base32>
	FloxSHA256 = "50d919fd8977510bf24433374b64672932f3d09115cb555a750647f8a2a8050f"

	// Claude Code: standalone binary from Anthropic's GCS bucket.
	// URL pattern: https://storage.googleapis.com/claude-code-dist-<bucket>/claude-code-releases/<version>/<platform>/claude
	// Platform key: aarch64-linux→linux-arm64, x86_64-linux→linux-x64
	ClaudeVersion = "2.1.138"
	// hex sha256 of the linux-arm64 binary (the VM image is Ubuntu 24.04 arm64).
	// NOT nix-prefetch-url base32. Computed via: nix hash convert --to base16 --hash-algo sha256 <base32>
	ClaudeSHA256 = "c01e68cb303f0edef3619da68e58f15a3b9638e4db936eaee644ec326e603aa3"

	// ClaudeGCSURL returns the GCS download URL for a given version and platform.
	// Platform must be one of: darwin-arm64, darwin-x64, linux-arm64, linux-x64.
	ClaudeGCSBucket = "86c565f3-f756-42ad-8dfa-d59b1c096819"
)

// BuildClaudeURL returns the GCS URL for the standalone Claude Code binary.
func BuildClaudeURL(version, platform string) string {
	return "https://storage.googleapis.com/claude-code-dist-" + ClaudeGCSBucket +
		"/claude-code-releases/" + version + "/" + platform + "/claude"
}