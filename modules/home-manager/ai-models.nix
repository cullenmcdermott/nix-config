# Model-tier configuration shared across AI coding agents (Claude Code, Codex).
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
  ...
}:
let
  cfg = config.cullen.ai;

  # Shared policy text; only the dispatch mechanics differ per harness.
  mkDelegationPolicy =
    {
      strong,
      weak,
      dispatch,
    }:
    ''
      ## Orchestrate, Don't Implement
      Model tiers on this system: strong = ${strong}, weak = ${weak}.
      Check which model you are running as. If you are the strong model, you are
      the tech lead, not the implementer:
      - Plan and decompose the work yourself; keep all architectural decisions.
      ${dispatch}
      - Review every diff a worker produces and verify with tests/commands
        yourself before accepting it. You own correctness; workers own keystrokes.
      - Implement directly only when the change is trivial (roughly: one file,
        <30 lines) or a worker has failed at the task twice.
      - Load the `delegation` skill before your first dispatch for prompt
        templates and the review loop.
      If you are the weak model, skip all of the above and implement directly.
    '';

  codexAgentsMd = ''
    ## Environment
    This is a Nix-managed system (nix-darwin + home-manager). All packages are
    declaratively managed. Never install packages imperatively (`brew install`,
    `npm install -g`, `pip install`, ...). For one-off commands use
    `nix run nixpkgs#<package>`; to search, `nix search nixpkgs <query>`.

    ## Verify Before Claiming
    Always verify state with actual commands before making claims. When
    debugging, form hypotheses and test them — do not state assumptions as fact.

    ${mkDelegationPolicy {
      strong = cfg.models.openai.strong;
      weak = cfg.models.openai.weak;
      dispatch = ''
        - Delegate implementation to weak-model workers via non-interactive
          exec, one task per invocation:
          `codex exec -m ${cfg.models.openai.weak} -c model_reasoning_effort=medium "<task>"`
          (drop to `model_reasoning_effort=low` for purely mechanical work).'';
    }}'';
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
          default = "claude-opus-4-8";
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
    # Rendered unconditionally so consumers can append it to their context
    # string without gating; the Codex files below are gated on enable.
    cullen.ai.claudeDelegationPolicy = mkDelegationPolicy {
      strong = cfg.models.anthropic.strong;
      weak = cfg.models.anthropic.weak;
      dispatch = ''
        - Delegate implementation to the `builder` agent and codebase
          exploration to the `Explore` agent — they are pinned to cheaper
          models. Dispatch independent tasks in parallel.'';
    };

    home.file = lib.mkIf cfg.enable {
      # Codex reads global instructions from ~/.codex/AGENTS.md. Its
      # config.toml is intentionally NOT managed here — codex rewrites it at
      # runtime (project trust levels, TUI state), so a store symlink would
      # break it.
      ".codex/AGENTS.md".text = codexAgentsMd;
      # Same delegation skill as Claude Code (Codex uses the same open skill
      # format under ~/.codex/skills/).
      ".codex/skills/delegation".source = ./../../skills/delegation;
    };
  };
}
