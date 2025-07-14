{ pkgs, lib, inputs, username, flakeRef, ... }:
{
  # Essential packages missing from Ubuntu base image
  # Note: git, curl, zsh are installed via apt in the distrobox init
  # Only add packages here that aren't already provided by home-manager
  home.packages = with pkgs; [
    gnupg        # For package verification  
    cacert       # For HTTPS certificates
  ];

  # Container-specific shell aliases
  programs.zsh.shellAliases = lib.mkForce {
    nixswitch = "home-manager switch --flake ${flakeRef}#${username}@distrobox";
    nixup = "pushd ~/src/nix-config; nix flake update; nixswitch; popd";
    host-cmd = "distrobox-host-exec";
    host-flatpak = "distrobox-host-exec flatpak";
  };

  # Ensure zsh is enabled
  programs.zsh.enable = true;
}