# Claude Code Nix Extensions
#
# This module provides options that supplement the upstream home-manager
# `programs.claude-code` module with Nix-specific features:
#   - LSP servers with absolute Nix store paths
#   - Custom statusline scripts
#   - Shell aliases for --plugin-dir injection
#   - Extra packages (playwright wrapper, bc for statusline)
#
# Use `programs.claude-code.*` (upstream) for: settings, skills, agents,
# commands, hooks, mcpServers, memory, rules, outputStyles, package.
# Use `programs.claude-code-nix.*` (this module) for the above extras.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.claude-code-nix;

  # Plugin directory for LSP servers
  lspPluginDir = "${config.home.homeDirectory}/.claude/custom-plugins";

  # Default starship-style statusline script
  # Line 1: model ─ branch ─ tokens ctx-bar · $cost
  # Line 2: usage bars (5h / weekly) with · separators
  # Line 3: reset times (5h / weekly)
  defaultStatusLineScript = ''
    #!${pkgs.bash}/bin/bash
    # Starship-style statusline for Claude Code

    # Error handling - always output something
    trap 'echo "Claude"' ERR

    # ── Color definitions (starship-inspired palette) ──────────────────
    BLUE='\033[38;2;82;139;255m'
    PURPLE='\033[38;2;187;154;255m'
    CYAN='\033[38;2;86;211;232m'
    GREEN='\033[38;2;80;250;123m'
    ORANGE='\033[38;2;255;176;85m'
    RED='\033[38;2;255;85;85m'
    YELLOW='\033[38;2;241;250;140m'
    DIM='\033[38;2;118;118;118m'
    RESET='\033[0m'
    BOLD='\033[1m'

    # ── Nerd Font icons ────────────────────────────────────────────────
    ICON_MODEL=""
    ICON_DIR="\033[38;2;82;139;255m"
    ICON_GIT="\033[38;2;187;154;255m"
    ICON_CTX=""
    ICON_COST="\033[38;2;241;250;140m"
    ICON_USAGE="\033[38;2;86;211;232m"
    ICON_RESET="\033[38;2;86;211;232m"
    ICON_INTERVAL="\033[38;2;86;211;232m"
    ICON_WEEKLY="\033[38;2;187;154;255m"

    # ── Segment separators ──────────────────────────────────────────────
    SEG="''${DIM} · ''${RESET}"
    SEGD="''${DIM} ─ ''${RESET}"

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
        tokens=''${tokens%.*}

        if [ $tokens -ge 1000000 ]; then
            local result=$(echo "scale=1; $tokens / 1000000" | ${pkgs.bc}/bin/bc)
            printf "%.1fm" $result
        elif [ $tokens -ge 1000 ]; then
            if [ $(( tokens % 1000 )) -eq 0 ]; then
                printf "%dk" $(( tokens / 1000 ))
            else
                local result=$(echo "scale=1; $tokens / 1000" | ${pkgs.bc}/bin/bc)
                printf "%.1fk" $result
            fi
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
        local pct_int=''${percent%.*}

        local filled=$(echo "scale=0; $pct_int * $width / 100" | ${pkgs.bc}/bin/bc)
        local empty=$((width - filled))

        local bar_color="''${GREEN}"
        if [ $(echo "$pct_int >= 75" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
            bar_color="''${RED}"
        elif [ $(echo "$pct_int >= 40" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
            bar_color="''${YELLOW}"
        fi

        local bar=""
        for ((i=0; i<filled; i++)); do bar="''${bar}●"; done
        for ((i=0; i<empty; i++)); do bar="''${bar}○"; done

        printf "''${bar_color}%.0f%% %s''${RESET}" "$percent" "$bar"
    }

    context_bar=$(build_context_bar $used_pct)


    # Extract session cost
    session_cost=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_cost_usd // 0')

    # Format cost display (subscription providers show no cost)
    cost_segment=""
    if [ "$session_cost" != "0" ] && [ "$session_cost" != "null" ] && [ "$session_cost" != "0.0" ]; then
        cost_fmt=$(printf "%.4f" "$session_cost" 2>/dev/null || echo "0.0000")
        cost_segment="''${SEG}''${ICON_COST}\$''${RESET}''${YELLOW}''${cost_fmt}''${RESET}"
    fi

    # Get git branch if in a repo
    git_segment=""
    if ${pkgs.git}/bin/git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(${pkgs.git}/bin/git -C "$current_dir" branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            git_segment="''${DIM} ─ ''${RESET}''${ICON_GIT}''${PURPLE}''${BOLD}''${branch}''${RESET}"
        fi
    fi

    # ── LINE 1: model ─ branch ─ tokens  ctx-bar  · $cost ─────────────
    printf "''${ICON_MODEL}''${BLUE}''${BOLD}%s''${RESET}%b''${SEGD}%s/''${ORANGE}%s''${RESET} %b%b\n" \
        "$model" "$git_segment" "$current_display" "$total_display" "$context_bar" "$cost_segment"

    CACHE_FILE="/tmp/claude-statusline-usage-cache.json"
    CACHE_TTL=60

    is_cache_valid() {
        if [ ! -f "$CACHE_FILE" ]; then
            return 1
        fi
        local now=$(date +%s)
        local cache_mtime=$(date -r "$CACHE_FILE" +%s 2>/dev/null || echo 0)
        local age=$((now - cache_mtime))
        [ $age -lt $CACHE_TTL ]
    }

    fetch_usage_data() {

        local credentials=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$credentials" ]; then
            return 1
        fi
        local access_token=$(echo "$credentials" | ${pkgs.jq}/bin/jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        if [ -z "$access_token" ]; then
            return 1
        fi
        local response=$(${pkgs.curl}/bin/curl -s -H "Authorization: Bearer $access_token" \
                              -H "anthropic-beta: oauth-2025-04-20" \
                              "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            local has_data=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.five_hour // empty' 2>/dev/null)
            if [ -n "$has_data" ]; then
                echo "$response" > "$CACHE_FILE"
                return 0
            else
                rm -f "$CACHE_FILE"
                return 1
            fi
        fi
        return 1
    }


    # Convert epoch (seconds) to formatted date string using python3
    # (macOS date(1) lacks -r flag, python3 works everywhere)
    epoch_to_date() {
        local epoch_time=$1
        if [ -z "$epoch_time" ] || [ "$epoch_time" = "0" ]; then
            echo "N/A"
            return
        fi
        printf '%s' "$epoch_time" | ${pkgs.python3}/bin/python3 -c '
import sys, datetime
try:
    ts = float(sys.stdin.read().strip())
    print(datetime.datetime.fromtimestamp(ts).strftime("%b %d %I:%M %p"))
except:
    print("N/A")
'
    }

    format_reset_time_from_epoch() {
        epoch_to_date "$1"
    }

    build_bar() {
        local percent=$1
        local width=10
        local filled=$(echo "scale=0; $percent * $width / 100" | ${pkgs.bc}/bin/bc)
        local empty=$((width - filled))

        local bar_color="''${GREEN}"
        if [ $(echo "$percent >= 90" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
            bar_color="''${RED}"
        elif [ $(echo "$percent >= 70" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
            bar_color="''${YELLOW}"
        elif [ $(echo "$percent >= 50" | ${pkgs.bc}/bin/bc) -eq 1 ]; then
            bar_color="''${ORANGE}"
        fi

        local bar=""
        for ((i=0; i<filled; i++)); do bar="''${bar}●"; done
        for ((i=0; i<empty; i++)); do bar="''${bar}○"; done

        printf "''${bar_color}%s''${RESET}" "$bar"
    }

    format_reset_time() {
        local iso_time=$1
        if [ -z "$iso_time" ] || [ "$iso_time" = "null" ] || [ "$iso_time" = "N/A" ]; then
            echo "N/A"
            return
        fi
        local formatted=$(${pkgs.coreutils}/bin/date -d "$iso_time" "+%b %d %I:%M %p" 2>/dev/null)
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
        has_valid_data=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.five_hour // empty' 2>/dev/null)
        if [ -n "$has_valid_data" ]; then
            current_pct=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.five_hour.utilization // 0' 2>/dev/null)
            current_reset=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.five_hour.resets_at // "N/A"' 2>/dev/null)
            weekly_pct=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.seven_day.utilization // 0' 2>/dev/null)
            weekly_reset=$(echo "$usage_data" | ${pkgs.jq}/bin/jq -r '.seven_day.resets_at // "N/A"' 2>/dev/null)

            current_bar=$(build_bar $current_pct)
            weekly_bar=$(build_bar $weekly_pct)
            current_reset_fmt=$(format_reset_time "$current_reset")
            weekly_reset_fmt=$(format_reset_time "$weekly_reset")

            # Line 2: Usage bars
            printf "''${ICON_INTERVAL}''${DIM}5h:''${RESET} %s ''${CYAN}%.0f%%''${RESET}''${SEG}''${ICON_WEEKLY}''${DIM}weekly:''${RESET} %s ''${CYAN}%.0f%%''${RESET}\n" \
                "$current_bar" "$current_pct" "$weekly_bar" "$weekly_pct"

            # Line 3: Reset times
            printf "''${ICON_RESET}''${CYAN}%s''${RESET}''${SEG}''${ICON_RESET}''${DIM}weekly:''${RESET} ''${CYAN}%s''${RESET}\n" \
                "$current_reset_fmt" "$weekly_reset_fmt"
        fi
    fi

  '';

  # Resolve the statusline script text
  statusLineScriptText =
    if cfg.statusLine.scriptText != null
    then cfg.statusLine.scriptText
    else defaultStatusLineScript;


  # When a statusline package is set, use the binary directly; skip the script.
  useStatuslineBinary = cfg.statusLine.package != null;
in
{
  options.programs.claude-code-nix = {
    enable = lib.mkEnableOption "Nix-specific Claude Code extensions (LSP, statusline, aliases)";

    # --- LSP ---

    lsp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable the LSP plugin with Nix-managed language servers.";
      };

      servers = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = ''
          LSP server definitions. Use absolute Nix store paths for commands
          (e.g., "${"$"}{pkgs.gopls}/bin/gopls"). Composable by language name via mkMerge.
        '';
      };
    };

    # --- Status Line ---

    statusLine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable the custom status line.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = ''
          A static binary to use as the statusline command (e.g. claude-statusline).
          When set, the binary is used directly instead of the bash script — no
          runtime dependencies on jq, bc, python3, or coreutils.  This is the
          recommended mode for sandbox VMs and portable installs.
        '';
      };

      scriptText = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Custom statusline script. null uses the built-in starship-style statusline. Ignored when package is set.";
      };
    };

    # --- MCP Servers ---

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        MCP server definitions. Written to ~/.claude/mcp.json which Claude Code
        auto-reads. Use this instead of upstream programs.claude-code.mcpServers
        since the upstream approach wraps the Nix binary (which is shadowed by
        the auto-updater binary).
      '';
    };

    # --- Default Model ---

    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default model to pass via --model to claude aliases. null omits the flag.";
    };

    # --- Extra Packages ---

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install alongside Claude Code.";
    };



    # --- Home Assistant ---

    homeAssistant = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable Home Assistant mode.";
      };

      repoPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to the Home Assistant config repository.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Don't install the Nix claude binary — the auto-updater at ~/.local/bin/claude
    # takes precedence on PATH anyway. Only set a package if pinning a version.
    programs.claude-code.package = lib.mkDefault null;

    home.packages = (lib.optional (!useStatuslineBinary) pkgs.bc)
      ++ (lib.optional useStatuslineBinary cfg.statusLine.package)
      ++ cfg.extraPackages;

    home.file = {
      # Statusline script (only when not using the Go binary)
      ".claude/statusline-command.sh" = lib.mkIf (cfg.statusLine.enable && !useStatuslineBinary) {
        text = statusLineScriptText;
        executable = true;
      };

      # MCP server configuration (auto-read by Claude Code)
      ".claude/mcp.json" = lib.mkIf (cfg.mcpServers != { }) {
        text = builtins.toJSON { mcpServers = cfg.mcpServers; };
      };

      # LSP plugin manifest
      ".claude/custom-plugins/lsp-servers/.claude-plugin/plugin.json" = lib.mkIf cfg.lsp.enable {
        text = builtins.toJSON {
          name = "lsp-servers";
          description = "Nix-managed LSP servers for code intelligence";
          version = "1.0.0";
        };
      };

      # LSP server definitions
      ".claude/custom-plugins/lsp-servers/.lsp.json" = lib.mkIf (cfg.lsp.enable && cfg.lsp.servers != { }) {
        text = builtins.toJSON cfg.lsp.servers;
      };
    };

    # Shell aliases - inject --plugin-dir so LSP works without special invocation
    programs.zsh.shellAliases = lib.mkIf cfg.lsp.enable (
      let
        modelFlag = lib.optionalString (cfg.defaultModel != null) " --model ${cfg.defaultModel}";
      in
      {
        claude = "command claude --plugin-dir ${lspPluginDir}${modelFlag}";
        clod = "command claude --plugin-dir ${lspPluginDir}${modelFlag}";
      }
    );

    # Wire statusline into upstream settings if enabled
    programs.claude-code.settings = lib.mkIf cfg.statusLine.enable {
      statusLine = {
        type = "command";
        command =
          if useStatuslineBinary
          then "${lib.getExe cfg.statusLine.package}"
          else "${config.home.homeDirectory}/.claude/statusline-command.sh";
      };
    };

  };
}
