{ config, pkgs, ... }:
{
  imports = [
    ../../disko-config.nix
  ];

  # Desktop system configuration
  # Hardware-specific configuration will be imported separately

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [ "copytoram" ];

  # Additional debugging if needed
  # boot.kernelParams = [ "copytoram" "debug" ];

  # Ensure required modules are loaded early
  boot.initrd.availableKernelModules = [
    "xhci_pci" # USB 3.0
    "ahci" # SATA
    "nvme" # NVMe drives
    "usbhid" # USB devices
    "usb_storage" # USB storage
    "sd_mod" # SCSI disk support
  ];

  # Hibernation support - handled by disko configuration

  # Enable hibernate
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=3600
  '';

  # System-specific overrides can go here
  # Most configuration is handled by modules/nixos/

  # Additional packages specific to this system
  environment.systemPackages = with pkgs; [
    # Add any desktop-specific packages here
  ];
}
