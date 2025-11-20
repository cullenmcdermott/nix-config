{ pkgs, lib, ... }:

let
  # Temporarily disabled due to pyarrow issue #461396
  # claude-monitor = pkgs.callPackage ./claude-monitor.nix { };
  ccusage = pkgs.callPackage ./ccusage.nix { };
in
{
  # Custom packages available to home-manager
  home.packages = [
    # claude-monitor  # Disabled - waiting for protobuf fixes
    ccusage
  ];
}