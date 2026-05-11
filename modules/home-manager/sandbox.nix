{ config, lib, pkgs, ... }:

let
  cfg = config.programs.sandbox;
  outs = pkgs.callPackage ../../pkgs/sandbox { inherit (pkgs) pkgsCross; };
in
{
  options.programs.sandbox = {
    enable = lib.mkEnableOption "sandbox — per-project Lima VM wrapper for AI coding agents";
    package = lib.mkOption {
      type = lib.types.package;
      default = outs.sandbox;
      description = "The sandbox host binary.";
    };
    wrapperPackage = lib.mkOption {
      type = lib.types.package;
      default = outs.sandboxClaudeLinux;
      description = "The cross-compiled Linux/aarch64 in-VM wrapper binary.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.lima
      pkgs.mutagen
    ];
    home.sessionVariables.SANDBOX_CLAUDE_WRAPPER =
      "${cfg.wrapperPackage}/bin/sandbox-claude";
  };
}