# Public module exports. Downstream flakes (e.g. the work laptop config)
# import these directly via inputs.system-config.darwinModules.* and
# inputs.system-config.homeManagerModules.*.
#
# Optional modules close over this flake's own inputs so consumers don't need
# to declare flox, dagger, flox-agentic, or superpowers as local inputs.
{ self, inputs, ... }:
let
  # Factory for standalone home-manager configs (any non-NixOS / non-darwin
  # machine — Linux boxes, containers, the sandbox VM). Add an entry to
  # flake.homeConfigurations below, then on the target run:
  #   nix run home-manager -- switch --flake <repo>#<name>
  mkHome =
    {
      username,
      system,
      profile ? self.homeManagerModules.profiles.workstation,
      modules ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = { inherit username inputs; };
      # home.homeDirectory is set by base.nix (derived from username + platform).
      modules = [
        profile
        {
          home.username = username;
          programs.home-manager.enable = true;
        }
      ]
      ++ modules;
    };
in
{
  flake.lib.mkHome = mkHome;

  flake.darwinModules = {
    default = self.darwinModules.profiles.personalMac;
    base = ../modules/common;

    macDefaults = ../modules/darwin/mac-defaults.nix;
    nixGc = ../modules/darwin/nix-gc.nix;
    homebrewBase = ../modules/darwin/homebrew-base.nix;
    homebrewPersonal = ../modules/darwin/homebrew-personal.nix;

    flox =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        options.cullen.flox.enable = lib.mkEnableOption "Flox CLI";
        config = lib.mkIf config.cullen.flox.enable {
          environment.systemPackages = [
            inputs.flox.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];
        };
      };

    dagger =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        options.cullen.dagger.enable = lib.mkEnableOption "Dagger CLI";
        config = lib.mkIf config.cullen.dagger.enable {
          environment.systemPackages = [
            inputs.dagger.packages.${pkgs.stdenv.hostPlatform.system}.dagger
          ];
        };
      };

    profiles.personalMac = _: {
      imports = [
        self.darwinModules.base
        self.darwinModules.macDefaults
        self.darwinModules.nixGc
        self.darwinModules.homebrewBase
        self.darwinModules.homebrewPersonal
      ];
    };
  };

  flake.homeManagerModules = {
    # Compatibility alias — full opinionated profile (same content as default.nix).
    # Consumers wanting minimal layers should import named sub-modules directly.
    default = self.homeManagerModules.full;
    full = ../modules/home-manager;

    # Minimal layer — nix settings only. Downstream hosts must provide:
    #   home.username        (required)
    #   home.homeDirectory   (required)
    #   programs.home-manager.enable = true
    #   username in specialArgs
    base = ../modules/home-manager/base.nix;

    # Shell layer — xdg config, zsh, bat, fzf, starship, direnv.
    # Requires base (or a module that sets home.stateVersion).
    shell = ../modules/home-manager/shell.nix;

    # Development packages — the full package list with gdk, Kubernetes tools, etc.
    devPackages = ../modules/home-manager/dev-packages.nix;

    editor = ../modules/home-manager/nvim;
    claudeCode = ../modules/home-manager/claude-code.nix;
    sandbox = ../modules/home-manager/sandbox.nix;

    omp = _: {
      _module.args.superpowers = inputs.superpowers;
      imports = [ ../modules/home-manager/omp.nix ];
    };

    agenticSkills = { config, lib, ... }: {
      options.cullen.agenticSkills.enable = lib.mkEnableOption "Flox and Superpowers agentic skills for Claude Code";
      config = lib.mkIf config.cullen.agenticSkills.enable {
        # Superpowers is intentionally trimmed to the discipline skills; the
        # planning/process skills (brainstorming, writing-plans,
        # executing-plans, using-superpowers, code-review pair, ...) are
        # superseded by the OpenSpec flow (see skills/spec) and built-in
        # /code-review. The v5 code-reviewer agent no longer ships in v6.
        programs.claude-code.skills = {
          flox-environments = "${inputs.flox-agentic}/flox-plugin/skills/flox-environments";
          flox-services = "${inputs.flox-agentic}/flox-plugin/skills/flox-services";
          flox-builds = "${inputs.flox-agentic}/flox-plugin/skills/flox-builds";
          flox-containers = "${inputs.flox-agentic}/flox-plugin/skills/flox-containers";
          flox-publish = "${inputs.flox-agentic}/flox-plugin/skills/flox-publish";
          flox-sharing = "${inputs.flox-agentic}/flox-plugin/skills/flox-sharing";
          flox-cuda = "${inputs.flox-agentic}/flox-plugin/skills/flox-cuda";
          sp-using-git-worktrees = "${inputs.superpowers}/skills/using-git-worktrees";
          sp-subagent-driven-development = "${inputs.superpowers}/skills/subagent-driven-development";
          sp-test-driven-development = "${inputs.superpowers}/skills/test-driven-development";
          sp-systematic-debugging = "${inputs.superpowers}/skills/systematic-debugging";
          sp-dispatching-parallel-agents = "${inputs.superpowers}/skills/dispatching-parallel-agents";
          sp-verification-before-completion = "${inputs.superpowers}/skills/verification-before-completion";
        };
      };
    };

    profiles.workstation = _: {
      imports = [
        self.homeManagerModules.base
        self.homeManagerModules.shell
        self.homeManagerModules.devPackages
        self.homeManagerModules.editor
        self.homeManagerModules.claudeCode
      ];
    };

    profiles.vm = { pkgs, ... }: {
      imports = [
        self.homeManagerModules.profiles.workstation
        self.homeManagerModules.agenticSkills
      ];
      home.packages = [
        inputs.flox.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
      cullen.agenticSkills.enable = true;
    };
  };
  flake.homeConfigurations = {
    # arm64 sandbox VM (Lima) — workstation + agentic skills layer.
    vm = mkHome {
      username = "cullen";
      system = "aarch64-linux";
      profile = self.homeManagerModules.profiles.vm;
    };

    # Generic portable workstation configs. Pick the one matching the machine
    # (or copy a line for a new user/arch) and run:
    #   nix run home-manager -- switch --flake <repo>#cullen@x86_64-linux
    "cullen@x86_64-linux" = mkHome {
      username = "cullen";
      system = "x86_64-linux";
    };
    "cullen@aarch64-linux" = mkHome {
      username = "cullen";
      system = "aarch64-linux";
    };
  };
}
