# Flake module exposing the sandbox host binary, the cross-compiled in-VM
# binaries (sandbox-claude + claude-statusline), and the native host
# statusline binary.
{ ... }:
{
  perSystem = { pkgs, ... }:
    let
      outs = pkgs.callPackage ../pkgs/sandbox { inherit (pkgs) pkgsCross; };
    in
    {
      packages.sandbox = outs.sandbox;
      packages.sandbox-vm-binaries = outs.sandboxVmBinaries;
      packages.claude-statusline = outs.claudeStatusline;

      # Backward compat alias — anything referencing the old name keeps working.
      packages.sandbox-claude-linux = outs.sandboxVmBinaries;
    };
}
