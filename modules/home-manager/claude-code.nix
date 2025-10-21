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

          # Context7 MCP tools (documentation)
          "mcp__context7__resolve-library-id"
          "mcp__context7__get-library-docs"

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

  # Custom slash command for handover preparation
  home.file.".claude/commands/handover.md" = {
    text = ''
      ---
      description: Prepare handover summary for new conversation when running out of context
      ---

      You are being asked to prepare a handover summary for a new conversation. This happens when the current conversation is running out of context and needs to be continued in a fresh session.

      Before writing the handover summary:
      1. Check the current git status and include it in the handover context
      2. Preserve any active todo list state
      3. Note the current project name and working modes
      4. Identify what task or work was in progress

      Please call the `mcp__serena__prepare_for_new_conversation` tool to get instructions on how to summarize the current task progress and write it to a memory file for the next conversation to continue from where you left off.

      After writing the handover summary to memory, provide a clear prompt that I can copy and paste into the new conversation to continue the work seamlessly. The prompt MUST:
      1. Explicitly instruct the new LLM to activate the correct project first
      2. Specify the exact memory file name to read (e.g., "conversation_handover")
      3. Have the new LLM confirm understanding of the context before proceeding
      4. Resume any incomplete todo items or tasks
      5. Check current git status to see if anything changed since handover
      6. Ask any clarifying questions if additional context is needed from the user

      The tool will provide specific guidance on what information to include in the handover summary.
    '';
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

        # Serena - using Nix-installed version
        serena = {
          command = "serena";
          args = [ "start-mcp-server" ];
          env = { };
        };

        # Playwright MCP - using wrapper script to fix browser path issues
        # Fixes nixpkgs issue #443704 by using command line arguments instead of env vars
        playwright = {
          command = "mcp-server-playwright-wrapper";
          args = [ ];
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
      ${pkgs.yq-go}/bin/yq eval '.excluded_tools = ["replace_regex", "replace_symbol_body", "insert_after_symbol", "insert_before_symbol", "delete_lines", "insert_at_line", "replace_lines", "create_text_file", "remove_project", "execute_shell_command"]' -i "$SERENA_CONFIG"
    '';
    executable = true;
  };

  # Add yq for YAML manipulation and Playwright wrapper
  home.packages = [
    pkgs.yq-go
    # Playwright MCP wrapper script that fixes browser path issues
    (pkgs.writeShellScriptBin "mcp-server-playwright-wrapper" ''
      export PWMCP_PROFILES_DIR_FOR_TEST="$HOME/.pwmcp-profiles"
      exec ${pkgs.playwright-mcp}/bin/mcp-server-playwright \
        --executable-path "${pkgs.google-chrome}/bin/google-chrome-stable" \
        --browser chrome \
        "$@"
    '')
  ];

  # Auto-configure serena on home-manager activation
  home.activation.configureSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${config.home.homeDirectory}/.local/bin/configure-serena
  '';
}
