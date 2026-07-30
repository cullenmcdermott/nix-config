{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.programs.sandbox;
  system = pkgs.stdenv.hostPlatform.system;
  # The sandbox CLI is built by its own flake (referenced as the `sandbox`
  # input). It is no longer vendored in this repo.
  sandboxPkg = inputs.sandbox.packages.${system}.default;
  # Standalone statusline binary (extracted from the old embedded sandbox CLI).
  claudeStatusline = pkgs.callPackage ../../pkgs/claude-statusline { };
in
{
  options.programs.sandbox = {
    enable = lib.mkEnableOption "sandbox — run AI coding agents in remote Kubernetes sessions";
    package = lib.mkOption {
      type = lib.types.package;
      default = sandboxPkg;
      description = "The sandbox CLI binary.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      # Runtime dependency, not a build one: the sandbox CLI shells out to the
      # `mutagen` binary (resolved via PATH) to sync the workspace into the
      # remote session pod. Dropping it makes `sandbox sync`/`doctor` fail at
      # runtime rather than at eval time — keep it here.
      pkgs.mutagen
    ];

    # Use the Go statusline binary for Claude Code on the host. This is a
    # separate, self-contained binary (pkgs/claude-statusline) and does not
    # depend on the sandbox CLI.
    programs.claude-code-nix.statusLine.package = lib.mkDefault claudeStatusline;
  };
}
