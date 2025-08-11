{ pkgs, inputs, lib, ... }:

let
  # Use mcp-nixos flake directly - much cleaner!
  mcp-nixos = inputs.mcp-nixos.packages.${pkgs.system}.default;

  # kagimcp - using dream2nix for reproducible Python packaging
  kagimcp = inputs.dream2nix.lib.evalModules {
    packageSets.nixpkgs = pkgs;
    modules = [
      ./mcp-servers/kagimcp/default.nix
      {
        paths.projectRoot = inputs.kagimcp;
        paths.projectRootFile = "pyproject.toml";
        paths.package = inputs.kagimcp;
      }
    ];
  };

  # context7-mcp - TypeScript/Node.js package (keeping existing working version)
  context7-mcp = pkgs.stdenv.mkDerivation rec {
    pname = "context7-mcp";
    version = "1.0.14";
    
    src = inputs.context7-mcp;
    
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

  # serena - using dream2nix for reproducible Python packaging
  serena = inputs.dream2nix.lib.evalModules {
    packageSets.nixpkgs = pkgs;
    modules = [
      ./mcp-servers/serena/default.nix
      {
        paths.projectRoot = inputs.serena-mcp;
        paths.projectRootFile = "pyproject.toml";
        paths.package = inputs.serena-mcp;
      }
    ];
  };

in
{
  # Export each package individually - completely decoupled  
  inherit mcp-nixos context7-mcp;
  # Temporarily disabled to fix path issues
  # kagimcp = kagimcp.config.public;
  # serena = serena.config.public;
}