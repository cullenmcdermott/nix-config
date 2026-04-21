{ pkgs, lib, ... }:

# pi-coding-agent has no official Nix package (upstream issue #701: missing lockfile in npm tarball).
# Using npx wrapper following the same pattern as ccusage.nix.
# Auth tokens (including GitHub Copilot OAuth) are persisted to ~/.pi/agent/auth.json.
pkgs.writeShellScriptBin "pi" ''
  export PI_TELEMETRY=0
  exec ${pkgs.nodejs}/bin/npx --yes @mariozechner/pi-coding-agent "$@"
''
