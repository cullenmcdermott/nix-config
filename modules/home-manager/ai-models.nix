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
  pkgs,
  ...
}:
let
  cfg = config.cullen.ai;

  # Codex has no plugin/hook mechanism under Nix management (its config.toml is
  # runtime-owned, see below), so the ponytail skills are pinned and linked
  # directly instead of going through the marketplace route Claude Code uses in
  # default.nix. Bump rev+hash to update; the two harnesses track ponytail
  # independently by design (Claude Code auto-updates its plugin copy).
  ponytailSrc = pkgs.fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "2ed6c52c9d7e5e56942508591085fd45dea277d3";
    hash = "sha256-bGdXvzhWPwGdz3T2Yh2h6lf+3PBRFAfdBxP5pESmCHI=";
  };

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

    ## Ponytail (always on)
    Load the `ponytail` skill at the start of every coding task and keep it
    active for the whole task: YAGNI, reuse what's already here, stdlib and
    native platform features before dependencies, shortest working diff. It is
    never a licence to skip understanding the problem, validation, error
    handling, security, or accessibility. Use `ponytail-review` to check a diff
    for over-engineering. This mirrors the always-on ponytail plugin in Claude
    Code.

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
      # Ponytail: the core ruleset skill (kept always-on by the directive in
      # codexAgentsMd above) and the diff reviewer. The rest of the plugin's
      # skills (-audit, -debt, -gain, -help) are Claude-Code-only on purpose;
      # add them here the same way if they turn out to be useful under Codex.
      ".codex/skills/ponytail".source = "${ponytailSrc}/skills/ponytail";
      ".codex/skills/ponytail-review".source = "${ponytailSrc}/skills/ponytail-review";
    };
  };
}
