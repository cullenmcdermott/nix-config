# Claude Code Nix Extensions
#
# This module provides options that supplement the upstream home-manager
# `programs.claude-code` module with Nix-specific features:
#   - LSP servers with absolute Nix store paths
#   - Statusline (pkgs/claude-statusline Go binary)
#   - Shell aliases for --plugin-dir injection
#   - Extra packages
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

  claudeConfigDir = config.programs.claude-code.configDir;

  # Installs the Nix-generated settings.json as a regular writable file,
  # deep-merging over any existing file so runtime keys survive rebuilds.
  # Nix-declared keys win on conflict; jq's `*` merges objects but replaces
  # arrays (so permissions.allow is fully owned by Nix).
  mergeSettingsScript = pkgs.writeShellScript "claude-code-merge-settings" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
      ]
    }
    target="$1"
    generated="$2"
    if [ -L "$target" ]; then
      rm "$target"
    fi
    if [ -f "$target" ]; then
      tmp="$(mktemp "$target.merge.XXXXXX")"
      trap 'rm -f "$tmp"' EXIT
      jq --slurp '.[0] * .[1]' "$target" "$generated" > "$tmp"
      mv "$tmp" "$target"
    else
      cp "$generated" "$target"
    fi
    chmod 0644 "$target"
  '';

  # Claude Code only reads user-scope MCP servers from ~/.claude.json (which it
  # also writes at runtime), so merge them in at activation instead of writing a
  # file it ignores. ponytail: last-writer-wins if Claude Code is running during
  # a switch; restart the session if a server goes missing.
  mergeMcpScript = pkgs.writeShellScript "claude-code-merge-mcp" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
      ]
    }
    target="$1"
    servers="$2"
    [ -f "$target" ] || echo '{}' > "$target"
    tmp="$(mktemp "$target.merge.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    jq --slurp '.[0] + { mcpServers: ((.[0].mcpServers // {}) + .[1]) }' \
      "$target" "$servers" > "$tmp"
    mv "$tmp" "$target"
    chmod 0600 "$target"
  '';
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
    };

    # --- MCP Servers ---

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        MCP server definitions, merged into ~/.claude.json (user scope) at
        activation — the only place Claude Code reads user-scope servers from.
        Use this instead of upstream programs.claude-code.mcpServers since the
        upstream approach wraps the Nix binary (which is shadowed by the
        auto-updater binary).
      '';
    };

    # --- Default Model ---

    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Default model to pass via --model to claude aliases. null omits the flag.
        Note: because the aliases pass --model on every launch, an in-session
        /model change (even when Claude "saves it as default") only lasts for
        that session — the next launch overrides it with this value. This is
        intentional: this option is the source of truth for new sessions.
      '';
    };

    # --- Mutable settings.json ---

    mutableSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install settings.json as a regular writable file instead of a
        read-only Nix store symlink. Runtime commands that persist to user
        settings (/effort, /config, "always allow" prompts) fail with EACCES
        against the symlink. When enabled, activation deep-merges the
        Nix-generated settings over the existing file: Nix-declared keys are
        reasserted on every rebuild, while keys only ever set at runtime
        survive between rebuilds.
      '';
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

    home.packages = cfg.extraPackages;

    home.file = {
      # LSP plugin manifest
      ".claude/custom-plugins/lsp-servers/.claude-plugin/plugin.json" = lib.mkIf cfg.lsp.enable {
        text = builtins.toJSON {
          name = "lsp-servers";
          description = "Nix-managed LSP servers for code intelligence";
          version = "1.0.0";
        };
      };

      # LSP server definitions
      ".claude/custom-plugins/lsp-servers/.lsp.json" =
        lib.mkIf (cfg.lsp.enable && cfg.lsp.servers != { })
          {
            text = builtins.toJSON cfg.lsp.servers;
          };

      # Keep the upstream-generated settings.json out of the symlink tree;
      # the activation script below installs it as a writable file instead.
      # (enable=false still leaves .source readable for the script.)
      "${claudeConfigDir}/settings.json" = lib.mkIf cfg.mutableSettings {
        enable = lib.mkForce false;
      };
    };

    home.activation.claudeCodeMutableSettings = lib.mkIf cfg.mutableSettings (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${mergeSettingsScript} ${lib.escapeShellArg "${claudeConfigDir}/settings.json"} \
          ${config.home.file."${claudeConfigDir}/settings.json".source}
      ''
    );

    home.activation.claudeCodeMcpServers = lib.mkIf (cfg.mcpServers != { }) (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${mergeMcpScript} ${lib.escapeShellArg "${config.home.homeDirectory}/.claude.json"} \
          ${pkgs.writeText "claude-mcp-servers.json" (builtins.toJSON cfg.mcpServers)}
      ''
    );

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
        command = lib.getExe (pkgs.callPackage ../../pkgs/claude-statusline { });
      };
    };

  };
}
