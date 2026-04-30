# Public module exports. Downstream flakes (e.g. the work laptop config)
# import these directly via inputs.system-config.darwinModules.* and
# inputs.system-config.homeManagerModules.*.
#
# Optional modules close over this flake's own inputs so consumers don't need
# to declare flox, dagger, flox-agentic, or superpowers as local inputs.
{ inputs, ... }:
{
  flake.darwinModules = {
    default = ../modules/darwin;
    shared = ../modules/common;
    base = ../modules/common;

    flox = { config, lib, pkgs, ... }: {
      options.cullen.flox.enable = lib.mkEnableOption "Flox CLI";
      config = lib.mkIf config.cullen.flox.enable {
        environment.systemPackages = [
          inputs.flox.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
      };
    };

    dagger = { config, lib, pkgs, ... }: {
      options.cullen.dagger.enable = lib.mkEnableOption "Dagger CLI";
      config = lib.mkIf config.cullen.dagger.enable {
        environment.systemPackages = [
          inputs.dagger.packages.${pkgs.stdenv.hostPlatform.system}.dagger
        ];
      };
    };
  };

  flake.homeManagerModules = {
    default = ../modules/home-manager;
    base = ../modules/home-manager;

    agenticSkills = { config, lib, ... }: {
      options.cullen.agenticSkills.enable = lib.mkEnableOption "Flox and Superpowers agentic skills for Claude Code";
      config = lib.mkIf config.cullen.agenticSkills.enable {
        programs.claude-code.agents = {
          code-reviewer = "${inputs.superpowers}/agents/code-reviewer.md";
        };
        programs.claude-code.skills = {
          flox-environments = "${inputs.flox-agentic}/flox-plugin/skills/flox-environments";
          flox-services = "${inputs.flox-agentic}/flox-plugin/skills/flox-services";
          flox-builds = "${inputs.flox-agentic}/flox-plugin/skills/flox-builds";
          flox-containers = "${inputs.flox-agentic}/flox-plugin/skills/flox-containers";
          flox-publish = "${inputs.flox-agentic}/flox-plugin/skills/flox-publish";
          flox-sharing = "${inputs.flox-agentic}/flox-plugin/skills/flox-sharing";
          flox-cuda = "${inputs.flox-agentic}/flox-plugin/skills/flox-cuda";
          sp-brainstorming = "${inputs.superpowers}/skills/brainstorming";
          sp-using-git-worktrees = "${inputs.superpowers}/skills/using-git-worktrees";
          sp-writing-plans = "${inputs.superpowers}/skills/writing-plans";
          sp-subagent-driven-development = "${inputs.superpowers}/skills/subagent-driven-development";
          sp-test-driven-development = "${inputs.superpowers}/skills/test-driven-development";
          sp-systematic-debugging = "${inputs.superpowers}/skills/systematic-debugging";
          sp-dispatching-parallel-agents = "${inputs.superpowers}/skills/dispatching-parallel-agents";
          sp-requesting-code-review = "${inputs.superpowers}/skills/requesting-code-review";
          sp-receiving-code-review = "${inputs.superpowers}/skills/receiving-code-review";
          sp-executing-plans = "${inputs.superpowers}/skills/executing-plans";
          sp-finishing-a-development-branch = "${inputs.superpowers}/skills/finishing-a-development-branch";
          sp-using-superpowers = "${inputs.superpowers}/skills/using-superpowers";
          sp-writing-skills = "${inputs.superpowers}/skills/writing-skills";
          sp-verification-before-completion = "${inputs.superpowers}/skills/verification-before-completion";
        };
      };
    };
  };
}
