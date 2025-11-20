{ pkgs, lib, ... }:

let
  ccusage = pkgs.callPackage ./ccusage.nix { };
in
{
  # Custom packages available to home-manager
  home.packages = [
    ccusage
  ];
}