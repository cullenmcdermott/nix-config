{ lib, buildGoModule }:

buildGoModule {
  pname = "sandbox";
  version = "0.0.1-dev";

  src = lib.cleanSource ./.;

  # Set after the first `nix build` fails — copy the expected hash from the
  # error message into the literal here.
  vendorHash = lib.fakeHash;

  subPackages = [ "cmd/sandbox" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/cullenmcdermott/system-config/sandbox/internal/buildinfo.version=${self.version}"
  ];

  doCheck = true;

  meta = with lib; {
    description = "Per-project Lima VM wrapper for AI coding agents";
    license = licenses.mit;
    mainProgram = "sandbox";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
