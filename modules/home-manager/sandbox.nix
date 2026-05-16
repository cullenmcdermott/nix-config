{ config, lib, pkgs, ... }:

let
  cfg = config.programs.sandbox;
  outs = pkgs.callPackage ../../pkgs/sandbox { };
in
{
  options.programs.sandbox = {
    enable = lib.mkEnableOption "sandbox — per-project Lima VM wrapper for AI coding agents";
    package = lib.mkOption {
      type = lib.types.package;
      default = outs.sandbox;
      description = "The sandbox host binary.";
    };
    vmBinariesPackage = lib.mkOption {
      type = lib.types.package;
      default = outs.sandboxVmBinaries;
      description = ''
        Cross-compiled Linux/aarch64 binaries for the sandbox VM.
        Contains sandbox-claude (wrapper) and claude-statusline.
        Mounted into the VM at /var/sandbox/bin/.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.lima
      pkgs.mutagen
    ];
    # Point at sandbox-claude inside the combined VM binaries package.
    # The sandbox host binary mounts filepath.Dir(this) into /var/sandbox/bin/,
    # which exposes every binary in the package (sandbox-claude, claude-statusline).
    home.sessionVariables.SANDBOX_CLAUDE_WRAPPER =
      "${cfg.vmBinariesPackage}/bin/sandbox-claude";

    # Use the Go statusline binary on the host too — same binary that runs
    # inside the VM, compiled natively for the host platform.
    programs.claude-code-nix.statusLine.package = lib.mkDefault outs.claudeStatusline;
  };
}