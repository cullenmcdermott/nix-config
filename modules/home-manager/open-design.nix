{ config, lib, pkgs, ... }:

let
  cfg = config.cullen.open-design;

  od = pkgs.callPackage ./packages/open-design.nix {};

  # Default app config that mirrors OMP's provider/model preferences.
  # Keys mirror AppConfigPrefs in apps/daemon/src/app-config.ts
  defaultAppConfig = {
    onboardingCompleted = true;
    agentId = cfg.defaultAgent;
    agentModels = lib.optionalAttrs (cfg.defaultModel != "default") {
      ${cfg.defaultAgent} = {
        model = cfg.defaultModel;
      };
    };
    skillId = "web-prototype";
    designSystemId = "default";
  };
in
{
  options.cullen.open-design = {
    enable = lib.mkEnableOption "open-design local design environment";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/open-design/data";
      description = "Runtime data directory for open-design (projects, sqlite, config)";
    };

    defaultAgent = lib.mkOption {
      type = lib.types.enum [ "claude" "copilot" "opencode" "codex" ];
      default = "copilot";
      description = ''
        Default coding agent that open-design spawns.
        Set to the same provider OMP uses for a consistent model experience.
        - "copilot"  → GitHub Copilot CLI (matches OMP's defaultProvider = github-copilot)
        - "claude"   → Claude Code (already installed via programs.claude-code)
        - "opencode" → OpenCode CLI
        - "codex"    → OpenAI Codex CLI
      '';
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "claude-sonnet-4.6";
      description = ''
        Default model passed to the agent.
        "default" lets the CLI pick its own default.
      '';
    };

    installCopilot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the GitHub Copilot CLI (copilot binary).
        Required if defaultAgent = "copilot".
      '';
    };

    installOpencode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the OpenCode CLI (opencode binary).
        Matches OMP's opencode-go provider.
      '';
    };

    installCodex = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the OpenAI Codex CLI (codex binary).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ od ]
      ++ lib.optional cfg.installCopilot pkgs.github-copilot-cli
      ++ lib.optional cfg.installOpencode pkgs.opencode
      ++ lib.optional cfg.installCodex pkgs.codex;

    # Seed the initial app-config so the first run already has the same
    # agent/model defaults as OMP. We only write it if absent so the UI
    # can mutate it later without home-manager fighting back.
    home.activation.openDesignConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      configFile="${cfg.dataDir}/app-config.json"
      if [[ ! -f "$configFile" ]]; then
        run mkdir -p "${cfg.dataDir}"
        run ${pkgs.jq}/bin/jq -n '${builtins.toJSON defaultAppConfig}' > "$configFile"
      fi
    '';
  };
}
