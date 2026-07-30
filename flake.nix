{
  description = "cullen's multi-platform nix configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.flox.dev"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Temporary pin: watchexec fails to link on aarch64-darwin at current
    # nixpkgs-unstable (ld64 hardening SIGTRAP; Hydra is broken too). Fix is
    # NixOS/nixpkgs#536365, merged to staging-next 2026-07-15. Drop this input
    # once watchexec builds again on nixpkgs-unstable.
    nixpkgs-watchexec.url = "github:NixOS/nixpkgs/19a8a1e6d8b7315b6fd84e5a51977ce6f69d5a5b";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox/v1.13.2";

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    mac-app-util.url = "github:hraban/mac-app-util";

    flox-skills.url = "github:flox/flox-skills/v1.0.0";
    flox-skills.flake = false;

    superpowers.url = "github:obra/superpowers/v6.1.1";
    superpowers.flake = false;

    # The standalone sandbox CLI (remote-Kubernetes agent sessions). Local path
    # for now — not yet pushed to a remote. Swap to a tagged github: URL once it
    # is published, e.g. "github:cullenmcdermott/sandbox/v0.1.0".
    sandbox.url = "git+file:///Users/cullen/git/sandbox";
    sandbox.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      imports = [
        ./flake-modules/modules.nix
        ./flake-modules/per-system.nix
        ./flake-modules/sandbox.nix
        ./hosts/cullens-macbook-pro
      ];
    };
}
