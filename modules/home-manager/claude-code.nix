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
    rev = "f232228244495c018b3c1857436cf491ebb79bbb";
    hash = "sha256-/u7NC9opHNXh9kQMWYzeLyurdQPPHULiCTUbvTZsXeU=";
  };

  # Flox agentic skills from flake input
  floxAgentic = inputs.flox-agentic;

  # Agent OS from flake input - patched to work with nix symlinks
  # The original scripts use `find` without -L, which doesn't follow symlinks
  agentOS = pkgs.runCommand "agent-os-patched" { } ''
    cp -r ${inputs.agent-os} $out
    chmod -R u+w $out
    # Patch find commands to follow symlinks (required for nix store symlinks)
    sed -i 's/find "\$search_dir" -type f/find -L "\$search_dir" -type f/g' $out/scripts/common-functions.sh
  '';
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
        ];
      };
      interactiveMode = true;
      autoCompact = false;

      # Enable sandbox with auto-allow for bash commands
      sandbox = {
        enabled = true;
        autoAllowBashIfSandboxed = true;
      };

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

      # Handover Preparation

      You are preparing a handover summary for a new conversation. This happens when the current conversation is running out of context and needs to be continued in a fresh session.

      ## Phase 1: Gather State

      Collect the following information:

      ### Task State
      - Capture any active TodoWrite items (pending and in-progress)
      - Identify the primary task/goal of this session
      - Note any subtasks or next steps that were planned

      ### Session Knowledge
      - **Debugging findings**: What was learned while investigating (even if not solved)
      - **Failed approaches**: What was tried and didn't work (to avoid repeating)
      - **Key decisions**: Important choices made and their rationale
      - **Blockers**: Any issues preventing progress

      ## Phase 2: Write Handover

      Write a handover summary file to `/tmp/claude-handover.md`:

      ```markdown
      # Conversation Handover - [Brief Title]

      ## Session Context
      - **Date**: [today's date]
      - **Primary Goal**: [what we were trying to accomplish]

      ## Completed Work ✅
      [list of completed items with brief descriptions]

      ## In Progress 🔄
      [current task and its state]
      [any partial work or findings]

      ## Pending Tasks 📋
      [remaining todo items]

      ## Key Findings This Session
      - [important discoveries]
      - [failed approaches to avoid]
      - [decisions made and why]

      ## Blockers / Unknowns ❓
      [anything blocking progress]
      [questions that need answers]

      ## Next Steps for New Session
      1. [specific first action]
      2. [follow-up actions]
      ```

      ## Phase 3: Generate Continuation Prompt

      Provide a copy-pasteable prompt for the new conversation:

      ```
      I'm continuing work from a previous session. Please read the handover file at /tmp/claude-handover.md and:
      1. Summarize your understanding of what was accomplished and what needs to be done
      2. Ask any clarifying questions before proceeding
      3. Resume work on the pending tasks
      ```

      ## Handover Quality Checklist

      Before finishing, verify:
      - [ ] All in-progress work is documented with enough detail to resume
      - [ ] Failed approaches noted (so they won't be repeated)
      - [ ] Key decisions and rationale recorded
      - [ ] Continuation prompt is specific and actionable
      - [ ] Next session can start without user re-explaining the task
    '';
  };

  # Global CLAUDE.md for user-wide preferences
  home.file.".claude/CLAUDE.md" = {
    text = ''
      # Global Claude Code Instructions

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
      - Keep responses concise and focused
    '';
  };

  # Global MCP server configuration
  home.file.".claude/mcp.json" = {
    text = builtins.toJSON {
      mcpServers = {
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
      get_context_used() { echo "$input" | ${pkgs.jq}/bin/jq -r '.context.used // 0'; }
      get_context_limit() { echo "$input" | ${pkgs.jq}/bin/jq -r '.context.limit // 0'; }

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
      CONTEXT_USED=$(get_context_used)
      CONTEXT_LIMIT=$(get_context_limit)

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

      # Show context usage percentage
      if [ "$CONTEXT_USED" != "0" ] && [ "$CONTEXT_USED" != "null" ] && [ "$CONTEXT_LIMIT" != "0" ] && [ "$CONTEXT_LIMIT" != "null" ]; then
          CONTEXT_PCT=$(echo "scale=1; $CONTEXT_USED * 100 / $CONTEXT_LIMIT" | ${pkgs.bc}/bin/bc)
          CONTEXT_PCT_INT=$(echo "$CONTEXT_PCT / 1" | ${pkgs.bc}/bin/bc)

          # Color code based on usage: green (<50%), yellow (50-80%), red (>80%)
          if [ "$CONTEXT_PCT_INT" -lt 50 ]; then
              CONTEXT_COLOR="$GREEN"
          elif [ "$CONTEXT_PCT_INT" -lt 80 ]; then
              CONTEXT_COLOR="$YELLOW"
          else
              CONTEXT_COLOR="$YELLOW" # Using yellow for high usage (red might be too alarming)
          fi

          STATUS="$STATUS ''${CONTEXT_COLOR}📊 ''${CONTEXT_PCT}%''${RESET}"
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

  # Add bc for calculations and Playwright wrapper
  home.packages = [
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

  # Agent OS - install to $HOME/agent-os for the install scripts to work
  # The aos-project-install script expects Agent OS at $HOME/agent-os
  home.file."agent-os" = {
    source = agentOS;
    recursive = true;
  };
}
