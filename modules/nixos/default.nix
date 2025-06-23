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
  system.stateVersion = "24.05";
  
  # Allow unfree packages (needed for NVIDIA drivers, Steam, etc.)
  nixpkgs.config.allowUnfree = true;
  
  # User configuration
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "storage" ];
    shell = pkgs.zsh;
  };
  
  # Enable zsh system-wide
  programs.zsh.enable = true;
  
  # Basic system services
  services.openssh.enable = true;
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