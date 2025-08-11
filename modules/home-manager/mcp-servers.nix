{ pkgs, inputs, lib, ... }:


let
  # Use mcp-nixos flake directly - much cleaner!
  mcp-nixos = inputs.mcp-nixos.packages.${pkgs.system}.default;

  # kagimcp - using pip in a wrapper to handle dependencies not in nixpkgs
  kagimcp = pkgs.writeShellApplication {
    name = "kagimcp";
    runtimeInputs = [ pkgs.python312 pkgs.python312Packages.pip ];
    text = ''
      # Create a temporary venv and install deps
      export TMPDIR="''${TMPDIR:-/tmp}"
      VENV_DIR="$HOME/.cache/kagimcp-venv"
      
      if [[ ! -d "$VENV_DIR" ]]; then
        echo "Setting up kagimcp environment..." >&2
        ${pkgs.python312}/bin/python -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install -e ${inputs.kagimcp}
      fi
      
      exec "$VENV_DIR/bin/kagimcp" "$@"
    '';
  };

  # context7-mcp - TypeScript/Node.js package  
  context7-mcp = pkgs.stdenv.mkDerivation rec {
    pname = "context7-mcp";
    version = "1.0.14";
    
    src = inputs.context7-mcp; # Use flake input directly!
    
    nativeBuildInputs = [ pkgs.nodejs pkgs.nodePackages.typescript pkgs.bun ];
    
    buildPhase = ''
      export HOME=$TMPDIR
      # Use bun to install dependencies
      bun install --frozen-lockfile
      # Build with TypeScript 
      ${pkgs.nodePackages.typescript}/bin/tsc
      chmod +x dist/index.js
    '';
    
    installPhase = ''
      mkdir -p $out/bin $out/lib/context7-mcp
      
      # Copy dist and node_modules
      cp -r dist $out/lib/context7-mcp/
      cp -r node_modules $out/lib/context7-mcp/
      cp package.json $out/lib/context7-mcp/
      
      # Create executable wrapper 
      cat > $out/bin/context7-mcp << EOF
#!/usr/bin/env bash
cd $out/lib/context7-mcp
exec ${pkgs.nodejs}/bin/node dist/index.js "\$@"
EOF
      chmod +x $out/bin/context7-mcp
    '';
    
    meta = with lib; {
      description = "MCP server for Context7";
      homepage = "https://github.com/upstash/context7-mcp";
      license = licenses.mit;
      mainProgram = "context7-mcp";
    };
  };

  # serena - using pip in a wrapper to handle dependencies not in nixpkgs  
  serena = pkgs.writeShellApplication {
    name = "serena";
    runtimeInputs = [ pkgs.python311 pkgs.python311Packages.pip ];
    text = ''
      # Create a persistent venv and install deps
      export TMPDIR="''${TMPDIR:-/tmp}"
      VENV_DIR="$HOME/.cache/serena-venv"
      
      if [[ ! -d "$VENV_DIR" ]]; then
        echo "Setting up serena environment..." >&2
        ${pkgs.python311}/bin/python -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install -e ${inputs.serena-mcp}
      fi
      
      exec "$VENV_DIR/bin/serena" "$@"
    '';
  };

in
{
  # Export each package individually - completely decoupled
  inherit mcp-nixos kagimcp context7-mcp serena;
}