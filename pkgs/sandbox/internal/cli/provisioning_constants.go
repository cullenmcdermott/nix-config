package cli

// Pinned versions and SHA-256 digests for runtime-installed components.
// Bump these together; the provision script fails closed on checksum mismatch.
const (
	// Flox: https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb
	FloxVersion = "1.12.0"
	FloxURL     = "https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb"
	// nix-prefetch-url https://downloads.flox.dev/by-env/stable/deb/flox-1.12.0.aarch64-linux.deb
	FloxSHA256 = "03q5m2ighiq6fmd5bjqmj78g6ci9cxj4ndrk8kr0nlbpi7yiknah"

	// Claude Code: standalone binary from Anthropic's GCS bucket.
	// URL pattern: https://storage.googleapis.com/claude-code-dist-<bucket>/claude-code-releases/<version>/<platform>/claude
	// Platform key: aarch64-darwin→darwin-arm64, x86_64-darwin→darwin-x64, aarch64-linux→linux-arm64, x86_64-linux→linux-x64
	ClaudeVersion = "2.1.138"
	// sha256 of the linux-arm64 binary (the VM image is Ubuntu 24.04 arm64).
	// nix-prefetch-url https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.138/linux-arm64/claude
	ClaudeSHA256 = "18rsc1p35v24wsp6x4yvwhw9cfssy5c8x9lxc7rxw3iz635nh7n0"

	// ClaudeGCSURL returns the GCS download URL for a given version and platform.
	// Platform must be one of: darwin-arm64, darwin-x64, linux-arm64, linux-x64.
	ClaudeGCSBucket = "86c565f3-f756-42ad-8dfa-d59b1c096819"
)

// BuildClaudeURL returns the GCS URL for the standalone Claude Code binary.
func BuildClaudeURL(version, platform string) string {
	return "https://storage.googleapis.com/claude-code-dist-" + ClaudeGCSBucket +
		"/claude-code-releases/" + version + "/" + platform + "/claude"
}