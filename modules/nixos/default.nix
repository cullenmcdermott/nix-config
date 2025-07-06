{
  pkgs,
  lib,
  config,
  username,
  inputs,
  ...
}:
{
  imports = [
    ./gaming.nix
    ./desktop.nix
    ./overlays.nix
  ];

  # Basic NixOS system configuration
  system.stateVersion = "25.05";
  
  # Allow unfree packages (needed for NVIDIA drivers, Steam, etc.)
  nixpkgs.config.allowUnfree = true;
  
  # Make user trusted for Nix daemon
  nix.settings.trusted-users = [ username "@wheel" ];
  
  # Standard filesystem support  
  boot.supportedFilesystems = [ "ext4" ];
  
  
  # User configuration
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "storage" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGjcXZICP2oHyzA97OmPRCKReZdLDahAwDZK7eV8ild"
    ];
  };
  
  # Enable zsh system-wide
  programs.zsh.enable = true;
  
  # SSH configuration for nixos-anywhere
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  
  networking.networkmanager.enable = true;
  
  # Enable sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  
  # Basic packages
  environment.systemPackages = with pkgs; [
    firefox
    git
    vim
  ];
}