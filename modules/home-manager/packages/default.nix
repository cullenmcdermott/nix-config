{ pkgs, lib, ... }:

let
  claude-monitor = pkgs.callPackage ./claude-monitor.nix { };
  ccusage = pkgs.callPackage ./ccusage.nix { };
in
{
  # Custom packages available to home-manager
  home.packages = [
    claude-monitor
    ccusage
  ];
}