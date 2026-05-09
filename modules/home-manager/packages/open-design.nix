{ pkgs }:
let
  src = pkgs.fetchFromGitHub {
    owner = "nexu-io";
    repo = "open-design";
    rev = "10e8e2d38d91d043185457e8b76885f160b9ff7b";
    hash = "sha256-vd1L9azumo3ZefCZ4+VNsSVuyZglKt10R3zy8WdznM8=";
  };

  srcHash = builtins.hashString "sha256" (builtins.toString src);

  odLauncher = pkgs.writeShellScriptBin "open-design" ''
    set -euo pipefail

    OD_DIR="''${OD_DIR:-$HOME/.local/share/open-design}"
    OD_DATA_DIR="''${OD_DATA_DIR:-$HOME/.local/share/open-design/data}"
    export OD_DATA_DIR

    # Check if source needs updating (Nix derivation changed)
    if [[ ! -f "$OD_DIR/.nix-src-hash" ]] || [[ "$(cat "$OD_DIR/.nix-src-hash")" != "${srcHash}" ]]; then
      echo "[open-design] Setting up / updating workspace..."
      rm -rf "$OD_DIR"
      mkdir -p "$OD_DIR"
      cp -r ${src}/* "$OD_DIR/"
      echo "${srcHash}" > "$OD_DIR/.nix-src-hash"
      chmod -R u+w "$OD_DIR"

      cd "$OD_DIR"
      ${pkgs.nodejs_24}/bin/corepack enable
      ${pkgs.nodejs_24}/bin/corepack pnpm install

      echo "[open-design] Workspace ready"
    fi

    cd "$OD_DIR"

    # Ensure data dir exists
    mkdir -p "$OD_DATA_DIR"

    # Export OD_BIN so media generation and od CLI work
    export OD_BIN="$OD_DIR/apps/daemon/dist/cli.js"

    # Build daemon if needed
    if [[ ! -f "$OD_BIN" ]]; then
      echo "[open-design] Building daemon..."
      ${pkgs.nodejs_24}/bin/corepack pnpm --filter @open-design/daemon build
    fi

    # Build web static export if needed
    if [[ ! -d "$OD_DIR/apps/web/out/index.html" ]] && [[ ! -f "$OD_DIR/apps/web/out/index.html" ]]; then
      echo "[open-design] Building web..."
      ${pkgs.nodejs_24}/bin/corepack pnpm build
    fi

    # Re-export in case builds changed it
    export OD_BIN="$OD_DIR/apps/daemon/dist/cli.js"

    exec ${pkgs.nodejs_24}/bin/corepack pnpm tools-dev "$@"
  '';
in
odLauncher
