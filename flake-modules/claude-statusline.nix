# Flake module exposing the native host claude-statusline binary.
_:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.claude-statusline = pkgs.callPackage ../pkgs/claude-statusline { };
    };
}
