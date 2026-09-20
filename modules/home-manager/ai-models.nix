# Shared configuration for Claude Code, Codex, and OpenCode.
#
# Defines the "strong" (orchestrator) and "weak" (implementation worker) model
# per provider, generates the delegation policy text injected into each
# harness's global context, and manages the Codex-side files (~/.codex/AGENTS.md
# and the shared `delegation` skill).
#
# To retune the tiers, change `cullen.ai.models.*` where this module is enabled
# (modules/home-manager/default.nix) and rebuild.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cullen.ai;

  # Pin the same portable ponytail skills for all three harnesses.
  ponytailSrc = pkgs.fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "2ed6c52c9d7e5e56942508591085fd45dea277d3";
    hash = "sha256-bGdXvzhWPwGdz3T2Yh2h6lf+3PBRFAfdBxP5pESmCHI=";
  };

  sharedSkills = config.programs.claude-code.skills;
  sharedMcp = config.programs.claude-code-nix.mcpServers;
  codexSettings = {
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    sandbox_mode = "workspace-write";
    mcp_servers = lib.mapAttrs (
      _: server:
      if server ? url then
        { inherit (server) url; }
      else
        {
          inherit (server) command;
          args = server.args or [ ];
          env = server.env or { };
        }
    ) sharedMcp;
  };
  mergePython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);

in
{
  options.cullen.ai = {
    enable = lib.mkEnableOption "shared AI model-tier config and Codex agent files";

    models = {
      anthropic = {
        strong = lib.mkOption {
          type = lib.types.str;
          default = "claude-fable-5";
          description = "Anthropic orchestrator model (planning, review, verification).";
        };
        weak = lib.mkOption {
          type = lib.types.str;
          default = "claude-opus-5";
          description = "Anthropic worker model (delegated implementation, cheap reviewers).";
        };
      };
      openai = {
        strong = lib.mkOption {
          type = lib.types.str;
          default = "gpt-5.6-sol";
          description = "OpenAI orchestrator model (Codex).";
        };
        weak = lib.mkOption {
          type = lib.types.str;
          # Full slug on purpose: the bare "gpt-5.6" alias routes to Sol.
          default = "gpt-5.6-terra";
          description = "OpenAI worker model (Codex delegated implementation), run at medium reasoning effort.";
        };
      };
    };

    claudeDelegationPolicy = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      internal = true;
      description = "Rendered delegation policy section for Claude Code's global context.";
    };
  };

  config = {
    cullen.ai.claudeDelegationPolicy = ''
      ## Ponytail (always on)
      Load the `ponytail` skill at the start of every coding task and keep it
      active throughout. Use `ponytail-review` to check the final diff.

      ## Delegation across harnesses
      All agents may request implementation, exploration, or peer review from
      Codex, Claude Code, or OpenCode using the shared `delegation` skill.
      Load it before dispatch. Prefer bounded worker tasks for substantial
      implementation; keep architecture and final verification with the parent.
      OpenAI tiers: strong = ${cfg.models.openai.strong}, weak = ${cfg.models.openai.weak}.
      Anthropic tiers: strong = ${cfg.models.anthropic.strong}, weak = ${cfg.models.anthropic.weak}.
      Use provider/model IDs in OpenCode. Workers implement their assigned task
      directly and do not delegate further unless explicitly asked.
      Pass the workspace, allowed changes, and permission restrictions to each
      child. Never use another harness to bypass a denied action or sandbox.
      Return blocked work to the parent for its normal approval process.
    '';

    programs.claude-code.skills = lib.mkIf cfg.enable (
      lib.genAttrs [
        "ponytail"
        "ponytail-review"
        "ponytail-audit"
        "ponytail-debt"
        "ponytail-gain"
        "ponytail-help"
      ] (name: "${ponytailSrc}/skills/${name}")
    );

    programs.claude-code-nix.mcpServers = lib.mkIf cfg.enable {
      featurescript = {
        type = "http";
        url = "https://fs-mcp.labs.onshape.app/mcp";
      };
    };

    # Keep the canonical context and complete skill set in Claude's existing
    # options, including skills contributed by other modules (Flox/Superpowers).
    home.file = lib.mkIf cfg.enable (
      {
        ".codex/AGENTS.md".text = config.programs.claude-code.context;
        ".config/opencode/AGENTS.md".text = config.programs.claude-code.context;
        # OpenCode merges this with runtime-owned opencode.jsonc.
        ".config/opencode/opencode.json".text = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          mcp = lib.mapAttrs (
            _: server:
            if server ? url then
              {
                type = "remote";
                inherit (server) url;
              }
            else
              {
                type = "local";
                command = [ server.command ] ++ (server.args or [ ]);
                environment = server.env or { };
              }
          ) sharedMcp;
        };
      }
      // lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".codex/skills/${name}" {
          inherit source;
          force = true;
        }
      ) sharedSkills
      // lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".config/opencode/skills/${name}" {
          inherit source;
          force = true;
        }
      ) sharedSkills
    );

    # Codex writes trust/TUI state here. Reassert declared keys on activation
    # while preserving runtime settings and TOML comments in a writable file.
    home.activation.codexSettings = lib.mkIf cfg.enable (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${mergePython}/bin/python3 ${../../scripts/merge-codex-settings.py} \
          ${lib.escapeShellArg "${config.home.homeDirectory}/.codex/config.toml"} \
          ${pkgs.writeText "codex-settings.json" (builtins.toJSON codexSettings)}
      ''
    );
  };
}
