{ lib, buildGoModule, ... }:

let version = "0.0.1-dev";
in buildGoModule {
  pname = "sandbox";
  inherit version;

  src = lib.cleanSource ./.;

  vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";

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
}
