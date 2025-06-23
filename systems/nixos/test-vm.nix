{ config, pkgs, ... }:
{
  # VM-specific configuration for testing
  
  # VM boot configuration - use systemd-boot for VM
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Smaller disk usage for VM
  documentation.enable = false;
  documentation.nixos.enable = false;
  
  # Enable graphics for desktop testing
  hardware.graphics.enable = true;
  
  # Lightweight desktop for VM testing
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.xfce.enable = true;
  };
  
  # VM testing packages
  environment.systemPackages = with pkgs; [
    firefox
    steam
    htop
    neofetch
  ];
  
  # Enable Steam for testing
  programs.steam.enable = true;
}