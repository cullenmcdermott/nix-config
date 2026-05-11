{ lib, buildGoModule, pkgsCross, ... }:

let
  version = "0.0.1-dev";
  src = lib.cleanSource ./.;
  vendorHash = "sha256-0vISaf3QmapQEet/2BAOqGP0/xW+FlhllrdMEDJU8VY=";
in
{
  sandbox = buildGoModule {
    pname = "sandbox";
    inherit version src vendorHash;

    subPackages = [ "cmd/sandbox" ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/cullenmcdermott/system-config/sandbox/internal/buildinfo.version=${version}"
    ];

    doCheck = true;

    meta = with lib; {
      description = "Per-project Lima VM wrapper for AI coding agents";
      license = licenses.mit;
      mainProgram = "sandbox";
      platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    };
  };

  sandboxClaudeLinux = pkgsCross.aarch64-multiplatform.buildGoModule {
    pname = "sandbox-claude-linux-arm64";
    inherit version src vendorHash;

    subPackages = [ "cmd/sandbox-claude" ];
    env.CGO_ENABLED = "0";
    ldflags = [ "-s" "-w" ];
    doCheck = false;
  };
}
