{
  lib,
  buildGoModule,
  ...
}:

# Starship-style statusline for Claude Code — a single self-contained, stdlib-only
# Go binary. Previously lived in pkgs/sandbox/cmd/claude-statusline; extracted so
# the statusline survives independently of the (removed) embedded sandbox CLI.
buildGoModule {
  pname = "claude-statusline";
  version = "0.0.1";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./main.go
    ];
  };

  # No third-party dependencies — nothing to vendor.
  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Starship-style statusline for Claude Code (static Go binary)";
    license = licenses.mit;
    mainProgram = "claude-statusline";
  };
}
