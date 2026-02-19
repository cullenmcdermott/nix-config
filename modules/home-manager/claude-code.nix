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
        command = "${config.home.homeDirectory}/.claude/statusline-command.sh";
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
      ## Sandbox Awareness
      - If a command fails with unexpected "permission denied", TLS errors, or connection refused, it is likely a sandbox restriction. Retry the command outside the sandbox before investigating other causes.

      ## Verify Before Claiming
      - Always verify state with actual commands before making claims. Do not assert that code isn't pushed, tags don't exist, or services aren't running without checking first.
      - When debugging, form hypotheses and test them with commands — do not state assumptions as fact.

      ## Destructive Changes
      - Before removing, deleting, or cleaning up resources, confirm the replacement is fully working first. Never prematurely remove old infrastructure during migrations.
      - For multi-step migrations: deploy new -> migrate data -> verify -> clean up old, with confirmation at each gate.

      ## Safety
      - When using `op` or another CLI command that will output sensitive information, never directly read the secrets — redact before printing to stdout.

      ## Preferences
      - Prefer Mermaid diagrams over ASCII diagrams.
      - When performing complex logic, write a script (preferably in python or go) and run it rather than trying to run/wrap all commands in a single bash -c or equivalent call
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

  # Rich 3-line status line script with API usage tracking
  home.file.".claude/statusline-command.sh" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      # Rich 3-line statusline for Claude Code on macOS
      # Ported from PowerShell version

      # Error handling - always output something
      trap 'echo "Claude"' ERR

      # Color definitions (matching PowerShell version)
      BLUE='\033[38;2;0;153;255m'
      ORANGE='\033[38;2;255;176;85m'
      GREEN='\033[38;2;0;160;0m'
      CYAN='\033[38;2;46;149;153m'
      RED='\033[38;2;255;85;85m'
      YELLOW='\033[38;2;230;200;0m'
      DIM='\033[2m'
      RESET='\033[0m'

      # Read JSON from stdin
      input=$(cat)

      # Extract model, context, and workspace info
      model=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "Unknown"')
      context_size=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.context_window_size // 0')
      used_pct=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // 0')
      current_dir=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cwd // .workspace.current_dir // "~"')
      dir_name=''${current_dir##*/}

      # Calculate current token usage
      input_tokens=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.current_usage.input_tokens // 0')
      output_tokens=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.current_usage.output_tokens // 0')
      cache_creation=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
      cache_read=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

      current_tokens=$((input_tokens + output_tokens + cache_creation + cache_read))

      # Format token counts with k/m suffixes
      format_tokens() {
          local tokens=$1
          # Convert to integer if it has decimals
          tokens=''${tokens%.*}

          if [ $tokens -ge 1000000 ]; then
              local result=$(echo "scale=1; $tokens / 1000000" | ${pkgs.bc}/bin/bc)
              printf "%.1fm" $result
          elif [ $tokens -ge 1000 ]; then
              local result=$(echo "scale=0; $tokens / 1000" | ${pkgs.bc}/bin/bc)
              printf "%.0fk" $result
          else
              printf "%d" $tokens
          fi
      }

      current_display=$(format_tokens $current_tokens)
      total_display=$(format_tokens $context_size)

      # Build context usage bar
      build_context_bar() {
          local percent=$1
          local width=10

          # Convert to integer
          local pct_int=''${percent%.*}

          # Calculate filled and empty dots
          local filled=$(echo "scale=0; $pct_int * $width / 100" | ${pkgs.bc}/bin/bc)
          local empty=$((width - filled))

          # Choose color based on percentage (Green: 0-39, Yellow: 40-74, Red: 75+)
          local bar_color="''${GREEN}"
          if [ $(echo "$pct_int >= 75" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
              bar_color="''${RED}"
          elif [ $(echo "$pct_int >= 40" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
              bar_color="''${YELLOW}"
          fi

          # Build bar string
          local bar=""
          for ((i=0; i<filled; i++)); do bar="''${bar}●"; done
          for ((i=0; i<empty; i++)); do bar="''${bar}○"; done

          # Return colored "22% ●●○○○○○○○○" format
          printf "''${bar_color}%.0f%% %s''${RESET}" "$percent" "$bar"
      }

      context_bar=$(build_context_bar $used_pct)

      # Extract session cost
      session_cost=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_cost_usd // 0')

      # Format cost display (only show if > 0)
      cost_display=""
      if [ "$session_cost" != "0" ] && [ "$session_cost" != "null" ] && [ "$session_cost" != "0.0" ]; then
          cost_fmt=$(printf "%.4f" "$session_cost" 2>/dev/null || echo "0.0000")
          cost_display=" ''${DIM}|''${RESET} ''${YELLOW}\$''${RESET}''${YELLOW}''${cost_fmt}''${RESET}"
      fi

      # Get git branch if in a repo
      git_info=""
      if ${pkgs.git}/bin/git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
          branch=$(${pkgs.git}/bin/git -C "$current_dir" branch --show-current 2>/dev/null)
          if [ -n "$branch" ]; then
              git_info=" ''${GREEN}($branch)''${RESET}"
          fi
      fi

      # Line 1: Model | dir (branch) | Tokens | Context Bar | $cost
      printf "''${BLUE}%s''${RESET} ''${DIM}|''${RESET} ''${CYAN}%s''${RESET}%b ''${DIM}|''${RESET} ''${ORANGE}%s''${RESET} ''${DIM}/''${RESET} ''${ORANGE}%s''${RESET} ''${DIM}|''${RESET} %b%b\n" \
          "$model" "$dir_name" "$git_info" "$current_display" "$total_display" "$context_bar" "$cost_display"

      # Cache configuration
      CACHE_FILE="/tmp/claude-statusline-usage-cache.json"
      CACHE_TTL=60

      # Function to check if cache is valid
      is_cache_valid() {
          if [ ! -f "$CACHE_FILE" ]; then
              return 1
          fi

          local now=$(date +%s)
          local cache_mtime=$(date -r "$CACHE_FILE" +%s 2>/dev/null || echo 0)
          local age=$((now - cache_mtime))

          [ $age -lt $CACHE_TTL ]
      }

      # Function to fetch usage data
      fetch_usage_data() {
          # Try to get OAuth token from Keychain
          local credentials=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
          if [ $? -ne 0 ] || [ -z "$credentials" ]; then
              return 1
          fi

          # Parse access token from credentials JSON
          local access_token=$(echo "$credentials" | ${pkgs.jq}/bin/jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
          if [ -z "$access_token" ]; then
              return 1
          fi

          # Fetch usage data from API
          local response=$(${pkgs.curl}/bin/curl -s -H "Authorization: Bearer $access_token" \
                                -H "anthropic-beta: oauth-2025-04-20" \
                                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

          if [ $? -eq 0 ] && [ -n "$response" ]; then
              # Validate response is actual usage data, not an error
              local has_data=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.five_hour // empty' 2>/dev/null)
              if [ -n "$has_data" ]; then
                  echo "$response" > "$CACHE_FILE"
                  return 0
              else
                  # Error response — remove stale cache so we retry next time
                  rm -f "$CACHE_FILE"
                  return 1
              fi
          fi

          return 1
      }

      # Function to build progress bar
      build_bar() {
          local percent=$1
          local width=10
          local filled=$(echo "scale=0; $percent * $width / 100" | ${pkgs.bc}/bin/bc)
          local empty=$((width - filled))

          # Choose color based on percentage
          local bar_color="''${GREEN}"
          if [ $(echo "$percent >= 90" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
              bar_color="''${RED}"
          elif [ $(echo "$percent >= 70" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
              bar_color="''${YELLOW}"
          elif [ $(echo "$percent >= 50" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
              bar_color="''${ORANGE}"
          fi

          # Build bar string
          local bar=""
          for ((i=0; i<filled; i++)); do bar="''${bar}●"; done
          for ((i=0; i<empty; i++)); do bar="''${bar}○"; done

          printf "''${bar_color}%s''${RESET}" "$bar"
      }

      # Function to format reset time
      format_reset_time() {
          local iso_time=$1
          if [ -z "$iso_time" ] || [ "$iso_time" = "null" ] || [ "$iso_time" = "N/A" ]; then
              echo "N/A"
              return
          fi

          # GNU date can parse ISO 8601 with timezone directly
          # Input format: 2026-02-15T19:00:00.882117+00:00
          local formatted=$(date -d "$iso_time" "+%b %d %I:%M %p" 2>/dev/null)
          if [ $? -eq 0 ]; then
              echo "$formatted"
          else
              echo "N/A"
          fi
      }

      # Get or fetch usage data
      usage_data=""
      if is_cache_valid; then
          usage_data=$(cat "$CACHE_FILE")
      else
          if fetch_usage_data; then
              usage_data=$(cat "$CACHE_FILE")
          fi
      fi

      # If we have usage data, display lines 2 and 3
      if [ -n "$usage_data" ]; then
          # Verify this is valid usage data (not a cached error)
          has_valid_data=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.five_hour // empty' 2>/dev/null)
          if [ -n "$has_valid_data" ]; then
              # Extract five_hour and seven_day data directly
              current_pct=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.five_hour.utilization // 0' 2>/dev/null)
              current_reset=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.five_hour.resets_at // "N/A"' 2>/dev/null)

              weekly_pct=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.seven_day.utilization // 0' 2>/dev/null)
              weekly_reset=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.seven_day.resets_at // "N/A"' 2>/dev/null)

              # Build bars
              current_bar=$(build_bar $current_pct)
              weekly_bar=$(build_bar $weekly_pct)

              # Format reset times
              current_reset_fmt=$(format_reset_time "$current_reset")
              weekly_reset_fmt=$(format_reset_time "$weekly_reset")

              # Line 2: Usage bars
              printf "''${DIM}Current (5h):''${RESET} %s ''${CYAN}%.0f%%''${RESET} ''${DIM}|''${RESET} ''${DIM}Weekly (7d):''${RESET} %s ''${CYAN}%.0f%%''${RESET}\n" \
                  "$current_bar" "$current_pct" "$weekly_bar" "$weekly_pct"

              # Line 3: Reset times
              printf "''${DIM}Resets:''${RESET} ''${CYAN}%s''${RESET} ''${DIM}|''${RESET} ''${DIM}Weekly:''${RESET} ''${CYAN}%s''${RESET}\n" \
                  "$current_reset_fmt" "$weekly_reset_fmt"
          fi
      fi
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

  home.file.".claude/skills/frontend-design" = {
    source = "${claudeSkills}/skills/frontend-design";
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
