{ pkgs, lib, inputs, ... }:

let
  ccusage = pkgs.callPackage ./ccusage.nix { };
  agent-os = pkgs.callPackage ./agent-os.nix { };
in
{
  # Custom packages available to home-manager
  home.packages = [
    ccusage
    agent-os
  ];
}