{ pkgs, ... }:

# ccusage is awkward to package declaratively (Bun deps), so this wrapper runs
# it via npx. Note: this fetches from the npm registry at runtime, so it needs
# network access and is not fully reproducible.
pkgs.writeShellScriptBin "ccusage" ''
  if ! command -v npx >/dev/null 2>&1; then
    echo "Error: npx not found. Please ensure Node.js is installed." >&2
    exit 1
  fi
  exec ${pkgs.nodejs}/bin/npx ccusage@15.2.0 "$@"
''
