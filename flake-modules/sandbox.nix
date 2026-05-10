# Flake module exposing the `sandbox` Go binary.
# Tests run via packages.sandbox (buildGoModule with doCheck = true),
# which has access to vendored modules and does not need network access.
{ ... }:
{
  perSystem = { pkgs, ... }: {
    packages.sandbox = pkgs.callPackage ../pkgs/sandbox { };
  };
}