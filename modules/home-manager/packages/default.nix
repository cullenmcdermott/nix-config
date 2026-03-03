{ pkgs, lib, inputs, claudeCodeOverrides ? {}, ... }:

let
  ccusage = pkgs.callPackage ./ccusage.nix { };
  agent-os = pkgs.callPackage ./agent-os.nix { };
  claude-code = pkgs.callPackage ./claude-code.nix claudeCodeOverrides;
in
{
  # Custom packages available to home-manager
  home.packages = [
    ccusage
    agent-os
    claude-code
    pkgs.cursor-cli # Cursor CLI (cursor-agent binary) for multi-LLM orchestration
  ];
}