{ config, pkgs, lib, ... }:

{
  # Global Claude Code settings
  home.file.".claude/settings.json" = {
    text = builtins.toJSON {
      # Only allow read-only tools by default for security
      permissions = {
        allow = [
          "Read"
          "Glob" 
          "Grep"
          "LS"
          "WebFetch"
          "WebSearch"
          # Read-only bash commands only
          "Bash(ls:*)"
          "Bash(find:*)"
          "Bash(grep:*)"
          "Bash(rg:*)"
          "Bash(cat:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(git status)"
          "Bash(git log:*)"
          "Bash(git diff:*)"
          "Bash(git show:*)"
        ];
      };
      interactiveMode = true;
    };
  };

  # Global CLAUDE.md for user-wide preferences
  home.file.".claude/CLAUDE.md" = {
    text = ''
      # Global Claude Code Instructions

      ## CRITICAL STARTUP REQUIREMENTS
      **MUST DO FIRST**: Always call the initial instructions tool when starting any session to understand the project context and available tools.

      **NEW PROJECT SETUP**: If this is a new project or serena onboarding hasn't been performed, you MUST:
      1. Perform serena onboarding automatically 
      2. Set up the project with read-only mode enabled
      3. Configure serena to disable web dashboard popups

      ## Development Preferences
      - Follow existing code conventions and patterns in each project
      - Use the project's existing libraries and frameworks
      - Write concise, readable code with minimal comments unless requested
      - Always run linting and type checking after changes

      ## Security
      - Never commit secrets or API keys
      - Follow security best practices
      - Use environment variables for sensitive configuration

      ## Code Style
      - Prefer editing existing files over creating new ones
      - Use semantic/symbolic editing tools when available
      - Keep responses concise and focused
    '';
  };

  # Global MCP server configuration
  home.file.".claude/mcp.json" = {
    text = builtins.toJSON {
      servers = {
        # Context7 for documentation - using Nix-installed version
        context7 = {
          command = "context7-mcp";
          args = [];
          env = {};
        };
        
        # NixOS helper - using Nix-installed version
        nixos = {
          command = "mcp-nixos";
          args = [];
          env = {};
        };

        # Kagi search - using Nix-installed version
        # Requires KAGI_API_KEY environment variable
        # Set with: export KAGI_API_KEY=$(op read "op://Private/Kagi API/credential")
        kagi = {
          command = "kagimcp";
          args = [];
          env = {};
        };

        # Serena - using Nix-installed version
        serena = {
          command = "serena";
          args = [];
          env = {};
        };
      };
    };
  };

  # Script to configure serena with our global settings
  home.file.".local/bin/configure-serena" = {
    text = ''
      #!/usr/bin/env bash
      # Configure serena with our global preferences
      
      SERENA_CONFIG="$HOME/.serena/serena_config.yml"
      SERENA_DIR="$HOME/.serena"
      
      # Create serena directory if it doesn't exist
      mkdir -p "$SERENA_DIR"
      
      # If config doesn't exist, create minimal version
      if [[ ! -f "$SERENA_CONFIG" ]]; then
        cat > "$SERENA_CONFIG" << 'EOF'
      # Serena configuration
      projects: {}
      EOF
      fi
      
      # Use yq to merge our settings
      ${pkgs.yq-go}/bin/yq eval '.web_dashboard = false' -i "$SERENA_CONFIG"
      ${pkgs.yq-go}/bin/yq eval '.web_dashboard_open_on_launch = false' -i "$SERENA_CONFIG"
      ${pkgs.yq-go}/bin/yq eval '.excluded_tools = ["replace_regex"]' -i "$SERENA_CONFIG"
    '';
    executable = true;
  };
  
  # Add yq for YAML manipulation
  home.packages = [ pkgs.yq-go ];

  # Auto-configure serena on home-manager activation
  home.activation.configureSerena = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${config.home.homeDirectory}/.local/bin/configure-serena
  '';
}