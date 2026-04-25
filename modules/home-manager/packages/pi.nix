{ pkgs, lib, ... }:

# pi-coding-agent has no official Nix package (upstream issue #701: missing lockfile in npm tarball).
# Use a pinned npx wrapper for reproducibility.
# Auth tokens are persisted under $PI_CODING_AGENT_DIR/auth.json when that env var is set,
# otherwise pi falls back to ~/.pi/agent/auth.json.
pkgs.writeShellScriptBin "pi" ''
  export PI_TELEMETRY=0
  export PI_CODING_AGENT_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/pi/agent"
  exec ${pkgs.nodejs}/bin/npx --yes @mariozechner/pi-coding-agent@0.68.1 "$@"
''
