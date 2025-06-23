{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  # Enable Steam and gaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  
  # AMD CPU optimizations (stock kernel)
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  boot.kernelParams = [
    # AMD CPU optimizations
    "amd_pstate=active"
  ];
  
  # Gaming packages
  environment.systemPackages = with pkgs; [
    # Steam and gaming
    steam
    steamcmd
    steam-run
    
    # Game launchers and managers
    lutris              # Wine game manager (Epic, GOG, etc.)
    heroic              # Epic Games & GOG launcher
    
    # Gaming utilities
    gamemode
    gamescope
    mangohud
    
    # Wine for Windows games
    wineWowPackages.stable
    winetricks
    
    # Emulation
    retroarch
    
    # Performance monitoring
    htop
    nvtopPackages.full
  ];
  
  # Gamemode for performance optimization
  programs.gamemode.enable = true;
  
  # Audio optimizations for gaming
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  
  # Graphics drivers and hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  
  # Performance tweaks
  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;  # For games that need it
    "vm.swappiness" = 10;             # Reduce swapping for gaming
  };
  
  # Gaming-specific system optimizations
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];
  
  # Enable real-time scheduling for games
  security.rtkit.enable = true;
  
  # Networking optimizations for gaming
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl."net.core.default_qdisc" = "fq";
  boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr";
}