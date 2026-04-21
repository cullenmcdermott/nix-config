{ pkgs, claudeCodeOverrides ? {}, ... }:

let
  ccusage = pkgs.callPackage ./ccusage.nix { };
  depot-cli = pkgs.callPackage ./depot-cli.nix { };
  pi = pkgs.callPackage ./pi.nix { };
in
{
  # Custom packages available to home-manager
  # Note: claude-code binary is installed by programs.claude-code module
  home.packages = [
    ccusage
    depot-cli
    pi
    pkgs.cursor-cli # Cursor CLI (cursor-agent binary) for multi-LLM orchestration
  ];
}