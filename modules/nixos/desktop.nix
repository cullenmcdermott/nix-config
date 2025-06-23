{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Desktop environment (KDE Plasma 6 with Wayland for gaming)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  
  # NVIDIA drivers
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Use proprietary drivers for better gaming performance
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  
  # Enable Wayland support for NVIDIA
  environment.sessionVariables = {
    # NVIDIA Wayland support
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
  
  # Audio with low-latency for gaming
  security.rtkit.enable = true;
  
  # Gaming and productivity applications
  environment.systemPackages = with pkgs; [
    # Browsers
    zen-browser          # Custom overlay for Zen browser
    
    # Communication
    discord
    
    # Media and streaming
    obs-studio
    vlc
    
    # KDE applications (minimal set)
    kate
    dolphin
    konsole
    
    # Gaming utilities
    openrgb              # RGB lighting control for X470 Taichi
    
    # System monitoring
    htop
    nvtopPackages.nvidia # NVIDIA GPU monitoring
  ];
  
  # Font configuration (just JetBrains Mono as requested)
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
  
  # NVIDIA-specific hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];
  };
  
  # AMD CPU optimizations
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}