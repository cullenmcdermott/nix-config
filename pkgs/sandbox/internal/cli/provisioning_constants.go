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
	ClaudeSHA256 = "693ecca41a62d58fee660884bd982ca5cdeab5b277925fcdfe880cdf02f98671"

	// ClaudeGCSURL returns the GCS download URL for a given version and platform.
	// Platform must be one of: darwin-arm64, darwin-x64, linux-arm64, linux-x64.
	ClaudeGCSBucket = "86c565f3-f756-42ad-8dfa-d59b1c096819"
	// omp (Oh My Pi): standalone binary from GitHub releases.
	// URL pattern: https://github.com/can1357/oh-my-pi/releases/download/v<version>/<platform>
	// Platform key: aarch64→omp-linux-arm64, x86_64→omp-linux-x64
	OmpVersion = "14.9.3"
	// hex sha256 of the linux-arm64 binary.
	OmpSHA256 = "d8a0f46a3aa638ddaa681507e8b310f99791855413b48386244e850a6c001549"
)

// BuildClaudeURL returns the GCS URL for the standalone Claude Code binary.
func BuildClaudeURL(version, platform string) string {
	return "https://storage.googleapis.com/claude-code-dist-" + ClaudeGCSBucket +
		"/claude-code-releases/" + version + "/" + platform + "/claude"
}
// BuildOmpURL returns the GitHub releases URL for the omp binary.
func BuildOmpURL(version, arch string) string {
	platform := "omp-linux-arm64"
	if arch == "x86_64" {
		platform = "omp-linux-x64"
	}
	return "https://github.com/can1357/oh-my-pi/releases/download/v" + version + "/" + platform
}
