{ lib, buildGoModule, installShellFiles, ... }:

let
  version = "0.0.1-dev";
  src = lib.cleanSource ./.;
  vendorHash = "sha256-TRUwvIdxB0PF9KN5sIGpsyrk7s23jQxgIQz9wF/4o8Q=";
in
{
  sandbox = buildGoModule {
    pname = "sandbox";
    inherit version src vendorHash;

    subPackages = [ "cmd/sandbox" ];

    nativeBuildInputs = [ installShellFiles ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/cullenmcdermott/system-config/sandbox/internal/buildinfo.version=${version}"
    ];

    postInstall = ''
      installShellCompletion --cmd sandbox \
        --bash <($out/bin/sandbox completion bash) \
        --zsh <($out/bin/sandbox completion zsh) \
        --fish <($out/bin/sandbox completion fish)
    '';

    doCheck = true;

    meta = with lib; {
      description = "Per-project Lima VM wrapper for AI coding agents";
      license = licenses.mit;
      mainProgram = "sandbox";
      platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    };
  };

  # Cross-compiled static binaries for the Linux/arm64 sandbox VM.
  # Both sandbox-claude (wrapper) and claude-statusline land in the same
  # output directory so the single WrapperBinaryPath mount exposes both.
  sandboxVmBinaries = buildGoModule {
    pname = "sandbox-vm-binaries-linux-arm64";
    inherit version src vendorHash;

    subPackages = [ "cmd/sandbox-claude" "cmd/claude-statusline" ];
    # Use Go's built-in cross-compilation (not pkgsCross) so we get a truly
    # static binary with no Nix-store ELF interpreter dependency.  The Nix Go
    # wrapper overrides env.GOOS/GOARCH, so we set them in preBuild instead.
    preBuild = ''
      export CGO_ENABLED=0 GOOS=linux GOARCH=arm64
    '';
    # Go cross-compilation places the output in bin/${GOOS}_${GOARCH}/.
    # Flatten it so binaries live at $out/bin/<name> as expected.
    postInstall = ''
      mv $out/bin/linux_arm64/* $out/bin/
      rmdir $out/bin/linux_arm64
    '';
    ldflags = [ "-s" "-w" ];
    doCheck = false;
  };

  # Native claude-statusline for the macOS host.
  claudeStatusline = buildGoModule {
    pname = "claude-statusline";
    inherit version src vendorHash;

    subPackages = [ "cmd/claude-statusline" ];
    ldflags = [ "-s" "-w" ];
    doCheck = false;

    meta = with lib; {
      description = "Starship-style statusline for Claude Code (static Go binary)";
      license = licenses.mit;
      mainProgram = "claude-statusline";
    };
  };
}
