# Flake module exposing the standalone sandbox CLI (built from the `sandbox`
# flake input) and the native host claude-statusline binary.
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.sandbox = inputs.sandbox.packages.${system}.default;
      packages.claude-statusline = pkgs.callPackage ../pkgs/claude-statusline { };
    };
}
