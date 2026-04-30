{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.permittedInsecurePackages = [
    "google-chrome-144.0.7559.97"
  ];

  system.primaryUser = username;

  nix.settings.trusted-users = [
    username
    "@admin"
  ];
  environment.shells = [
    pkgs.zsh
    pkgs.bash
  ];
  environment.systemPackages = [
    pkgs.coreutils
  ];
  system.keyboard.enableKeyMapping = true;
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder._FXShowPosixPathInTitle = false;
  system.defaults.trackpad.TrackpadThreeFingerDrag = true;
  system.defaults.dock.orientation = "left";
  system.defaults.dock.autohide = true;
  system.defaults.dock.wvous-br-corner = 5;
  system.defaults.screensaver.askForPassword = true;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 14;
  system.defaults.NSGlobalDomain.KeyRepeat = 2;

  system.stateVersion = 6;
}
