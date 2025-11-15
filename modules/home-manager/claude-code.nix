{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Fetch the entire Claude Code skills repository
  claudeSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "main";
    hash = "sha256-5SxVADhG86yNe8tS7kC0Ruqmb/mTguz5I4Kv1GRBidY=";
  };

  # Flox agentic skills from flake input
  floxAgentic = inputs.flox-agentic;
in
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

      # Custom status line configuration
      statusLine = {
        type = "command";
        command = "${config.home.homeDirectory}/.claude/statusline.sh";
      };
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

  # Custom status line script with pwd, model, git branch, and usage stats
  home.file.".claude/statusline.sh" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      # Custom Claude Code status line showing pwd, model, git info, and usage stats

      # Read JSON input from stdin
      input=$(cat)

      # Helper functions for extracting values
      get_model_name() { echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "Unknown"'; }
      get_current_dir() { echo "$input" | ${pkgs.jq}/bin/jq -r '.cwd // .workspace.current_dir // "~"'; }
      get_cost() { echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_cost_usd // 0'; }
      get_tokens_input() { echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_input_tokens // 0'; }
      get_tokens_output() { echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_output_tokens // 0'; }
      get_lines_added() { echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_lines_added // 0'; }
      get_lines_removed() { echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_lines_removed // 0'; }

      # Extract core info
      MODEL=$(get_model_name)
      CURRENT_DIR=$(get_current_dir)
      DIR_NAME=''${CURRENT_DIR##*/}

      # ANSI color codes
      BLUE='\033[0;34m'
      GREEN='\033[0;32m'
      YELLOW='\033[0;33m'
      CYAN='\033[0;36m'
      MAGENTA='\033[0;35m'
      RESET='\033[0m'
      BOLD='\033[1m'

      # Build status line
      STATUS="''${BLUE}''${BOLD}[$MODEL]''${RESET}"

      # Add current directory
      STATUS="$STATUS ''${CYAN}📁 $DIR_NAME''${RESET}"

      # Check for git repository and branch
      if ${pkgs.git}/bin/git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
          BRANCH=$(${pkgs.git}/bin/git -C "$CURRENT_DIR" branch --show-current 2>/dev/null)
          if [ -n "$BRANCH" ]; then
              STATUS="$STATUS ''${GREEN}🌿 $BRANCH''${RESET}"
          fi
      fi

      # Add usage statistics
      COST=$(get_cost)
      TOKENS_IN=$(get_tokens_input)
      TOKENS_OUT=$(get_tokens_output)
      LINES_ADD=$(get_lines_added)
      LINES_REM=$(get_lines_removed)

      # Format cost (only show if > 0)
      if [ "$COST" != "0" ] && [ "$COST" != "null" ]; then
          COST_FORMATTED=$(printf "%.4f" "$COST")
          STATUS="$STATUS ''${YELLOW}💰 \$$COST_FORMATTED''${RESET}"
      fi

      # Show token counts (if any exist)
      if [ "$TOKENS_IN" != "0" ] && [ "$TOKENS_IN" != "null" ]; then
          # Format tokens with K suffix if > 1000
          if [ "$TOKENS_IN" -gt 1000 ]; then
              TOKENS_IN_K=$(echo "scale=1; $TOKENS_IN / 1000" | ${pkgs.bc}/bin/bc)
              TOKENS_IN_FMT="''${TOKENS_IN_K}K"
          else
              TOKENS_IN_FMT="$TOKENS_IN"
          fi

          if [ "$TOKENS_OUT" -gt 1000 ]; then
              TOKENS_OUT_K=$(echo "scale=1; $TOKENS_OUT / 1000" | ${pkgs.bc}/bin/bc)
              TOKENS_OUT_FMT="''${TOKENS_OUT_K}K"
          else
              TOKENS_OUT_FMT="$TOKENS_OUT"
          fi

          STATUS="$STATUS ''${MAGENTA}🔢 $TOKENS_IN_FMT↓/$TOKENS_OUT_FMT↑''${RESET}"
      fi

      # Show lines changed (if any)
      if [ "$LINES_ADD" != "0" ] || [ "$LINES_REM" != "0" ]; then
          if [ "$LINES_ADD" != "null" ] && [ "$LINES_ADD" != "0" ]; then
              STATUS="$STATUS ''${GREEN}+$LINES_ADD''${RESET}"
          fi
          if [ "$LINES_REM" != "null" ] && [ "$LINES_REM" != "0" ]; then
              STATUS="$STATUS ''${YELLOW}-$LINES_REM''${RESET}"
          fi
      fi

      # Output the status line (echo -e interprets escape sequences)
      echo -e "$STATUS"
    '';
    executable = true;
  };

  # Add yq for YAML manipulation, bc for calculations, and Playwright wrapper
  home.packages = [
    pkgs.yq-go
    pkgs.bc # For arithmetic in statusline script
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

  # Claude Code Skills
  # Copy entire skill directories from the fetched repository
  home.file.".claude/skills/slack-gif-creator" = {
    source = "${claudeSkills}/slack-gif-creator";
    recursive = true;
  };

  home.file.".claude/skills/skill-creator" = {
    source = "${claudeSkills}/skill-creator";
    recursive = true;
  };

  # Home Assistant skill - local custom skill
  home.file.".claude/skills/home-assistant" = {
    source = ./../../skills/home-assistant;
    recursive = true;
  };

  # Flox agentic skills - install each skill at top level
  # Claude Code scans ~/.claude/skills/*/SKILL.md, not nested directories
  home.file.".claude/skills/flox-environments" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-environments";
    recursive = true;
  };

  home.file.".claude/skills/flox-services" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-services";
    recursive = true;
  };

  home.file.".claude/skills/flox-builds" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-builds";
    recursive = true;
  };

  home.file.".claude/skills/flox-containers" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-containers";
    recursive = true;
  };

  home.file.".claude/skills/flox-publish" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-publish";
    recursive = true;
  };

  home.file.".claude/skills/flox-sharing" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-sharing";
    recursive = true;
  };

  home.file.".claude/skills/flox-cuda" = {
    source = "${floxAgentic}/flox-plugin/skills/flox-cuda";
    recursive = true;
  };
}
