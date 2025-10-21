{
  inputs,
  pkgs,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:

let
  # Reusable helper for building MCP packages with uv2nix
  mkMcpPackage =
    {
      name,
      workspaceRoot,
      pythonVersion,
      executables,
      overrides ? (_final: _prev: { }),
    }:
    let
      workspace = uv2nix.lib.workspace.loadWorkspace { inherit workspaceRoot; };
      overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
      pythonSet =
        (pkgs.callPackage pyproject-nix.build.packages {
          python = pythonVersion;
        }).overrideScope
          (
            pkgs.lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              overlay
              overrides
            ]
          );
      venv = pythonSet.mkVirtualEnv "${name}-env" workspace.deps.default;
    in
    pkgs.symlinkJoin {
      name = "${name}-mcp";
      paths = map (
        exe:
        pkgs.writeShellScriptBin exe ''
          exec ${venv}/bin/${exe} "$@"
        ''
      ) executables;
    };

in
{
  serena = mkMcpPackage {
    name = "serena";
    workspaceRoot = inputs.serena-mcp;
    pythonVersion = pkgs.python311;
    executables = [
      "serena"
      "serena-mcp-server"
    ];
    overrides = final: prev: {
      # Build fixups for serena dependencies
      ruamel-yaml-clib = prev.ruamel-yaml-clib.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          final.setuptools
          final.wheel
        ];
      });
    };
  };

  # TypeScript/Node.js packages that don't use the Python helper
  # playwright-mcp is now available in nixpkgs, so we use that instead

  context7-mcp = pkgs.stdenv.mkDerivation rec {
    pname = "context7-mcp";

    src = inputs.context7-mcp;

    # Extract version from package.json dynamically
    version = (builtins.fromJSON (builtins.readFile "${src}/package.json")).version;

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.bun
    ];

    configurePhase = ''
      runHook preConfigure
      export HOME=$TMPDIR
      export npm_config_cache=$TMPDIR/.npm
      runHook postConfigure  
    '';

    buildPhase = ''
      runHook preBuild

      # Install dependencies with bun (faster than npm)
      bun install --frozen-lockfile --no-progress

      # Build with bun (handles TypeScript natively)  
      bun run build || {
        echo "Build failed, trying manual TypeScript compilation..."
        ${pkgs.nodePackages.typescript}/bin/tsc
      }

      # Verify build output exists
      if [[ ! -f dist/index.js ]]; then
        echo "Error: Build output dist/index.js not found"
        exit 1
      fi

      # Make executable
      chmod +x dist/index.js

      runHook postBuild
    '';

    installPhase = ''
            runHook preInstall
            
            mkdir -p $out/bin $out/lib/context7-mcp
            
            # Copy only necessary files (not entire node_modules)
            cp -r dist $out/lib/context7-mcp/
            cp package.json $out/lib/context7-mcp/
            
            # Create optimized runtime with only production dependencies
            cd $out/lib/context7-mcp
            ${pkgs.bun}/bin/bun install --production --frozen-lockfile --no-progress
            
            # Create robust wrapper script
            cat > $out/bin/context7-mcp << EOF
      #!/usr/bin/env bash
      set -euo pipefail

      SCRIPT_DIR="$out/lib/context7-mcp"

      if [[ ! -d "\$SCRIPT_DIR" ]]; then
          echo "Error: context7-mcp installation directory not found" >&2
          exit 1
      fi

      if [[ ! -f "\$SCRIPT_DIR/dist/index.js" ]]; then
          echo "Error: context7-mcp main script not found" >&2  
          exit 1
      fi

      cd "\$SCRIPT_DIR"
      exec ${pkgs.nodejs}/bin/node dist/index.js "\$@"
      EOF
            chmod +x $out/bin/context7-mcp
            
            runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "MCP server for Context7 - Library documentation search";
      homepage = "https://github.com/upstash/context7-mcp";
      license = licenses.mit;
      mainProgram = "context7-mcp";
      platforms = platforms.all;
    };
  };
}
