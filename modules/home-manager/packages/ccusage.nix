{ pkgs, lib, ... }:

# Since ccusage is complex to package declaratively due to Bun dependencies,
# let's create a wrapper that uses npx when needed
pkgs.writeShellScriptBin "ccusage" ''
  # Check if ccusage is available in npm global
  if ! command -v npx >/dev/null 2>&1; then
    echo "Error: npx not found. Please ensure Node.js is installed."
    exit 1
  fi
  
  # Use npx to run ccusage directly from npm registry
  # This is more reliable than trying to package the complex TypeScript/Bun setup
  exec ${pkgs.nodejs}/bin/npx ccusage@15.2.0 "$@"
''