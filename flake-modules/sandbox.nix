# Flake module exposing the `sandbox` host binary and the `sandbox-claude`
# in-VM wrapper (cross-compiled to linux/arm64).
{ ... }:
{
  perSystem = { pkgs, ... }:
    let
      outs = pkgs.callPackage ../pkgs/sandbox { inherit (pkgs) pkgsCross; };
    in
    {
      packages.sandbox = outs.sandbox;
      packages.sandbox-claude-linux = outs.sandboxClaudeLinux;
    };
}
