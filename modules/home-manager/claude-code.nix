{
  config,
  pkgs,
  lib,
  ...
}:

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
          "Bash(mkdir:*)"
          "Bash(chmod:*)"
          # Additional useful bash commands
          "Bash(nix search:*)"
          "Bash(nix-env:*)"
          "Bash(time zsh:*)"
          "Bash(zsh:*)"

          # Kagi MCP tools
          "mcp__kagi__kagi_search_fetch"
          "mcp__kagi__kagi_summarizer"

          # Context7 MCP tools (documentation)
          "mcp__context7__resolve-library-id"
          "mcp__context7__get-library-docs"

          # NixOS MCP tools (all read-only)
          "mcp__nixos__nixos_search"
          "mcp__nixos__nixos_info"
          "mcp__nixos__nixos_channels"
          "mcp__nixos__nixos_stats"
          "mcp__nixos__nixos_flakes_search"
          "mcp__nixos__nixos_flakes_stats"
          "mcp__nixos__nixhub_package_versions"
          "mcp__nixos__nixhub_find_version"
          "mcp__nixos__home_manager_search"
          "mcp__nixos__home_manager_info"
          "mcp__nixos__home_manager_stats"
          "mcp__nixos__home_manager_list_options"
          "mcp__nixos__home_manager_options_by_prefix"
          "mcp__nixos__darwin_search"
          "mcp__nixos__darwin_info"
          "mcp__nixos__darwin_stats"
          "mcp__nixos__darwin_list_options"
          "mcp__nixos__darwin_options_by_prefix"

          # Serena MCP tools (read-only analysis)
          "mcp__serena__list_dir"
          "mcp__serena__find_file"
          "mcp__serena__search_for_pattern"
          "mcp__serena__get_symbols_overview"
          "mcp__serena__find_symbol"
          "mcp__serena__find_referencing_symbols"

          # Serena MCP tools (memory management)
          "mcp__serena__read_memory"
          "mcp__serena__list_memories"
          "mcp__serena__write_memory"
          "mcp__serena__delete_memory"

          # Serena MCP tools (project management)
          "mcp__serena__activate_project"
          "mcp__serena__check_onboarding_performed"
          "mcp__serena__onboarding"
          "mcp__serena__get_current_config"
          "mcp__serena__switch_modes"
          "mcp__serena__initial_instructions"
          "mcp__serena__prepare_for_new_conversation"

          # Serena MCP tools (thinking/analysis)
          "mcp__serena__think_about_collected_information"
          "mcp__serena__think_about_task_adherence"
          "mcp__serena__think_about_whether_you_are_done"

          # Serena MCP tools (safe operations)
          "mcp__serena__restart_language_server"
          "mcp__serena__summarize_changes"
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
      mcpServers = {
        # Context7 for documentation - using Nix-installed version
        context7 = {
          command = "context7-mcp";
          args = [ ];
          env = { };
        };

        # NixOS helper - using Nix-installed version
        nixos = {
          command = "mcp-nixos";
          args = [ ];
          env = { };
        };

        # Kagi search - using Nix-installed version
        # Requires KAGI_API_KEY environment variable
        # Set with: export KAGI_API_KEY=$(op read "op://Private/Kagi API/credential")
        kagi = {
          command = "kagimcp";
          args = [ ];
          env = { };
        };

        # Serena - using Nix-installed version
        serena = {
          command = "serena";
          args = [ "start-mcp-server" ];
          env = { };
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
      ${pkgs.yq-go}/bin/yq eval '.excluded_tools = ["replace_regex", "replace_symbol_body", "insert_after_symbol", "insert_before_symbol", "delete_lines", "insert_at_line", "replace_lines", "create_text_file", "remove_project"]' -i "$SERENA_CONFIG"
    '';
    executable = true;
  };

  # Add yq for YAML manipulation
  home.packages = [ pkgs.yq-go ];

  # Auto-configure serena on home-manager activation
  home.activation.configureSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${config.home.homeDirectory}/.local/bin/configure-serena
  '';
}
