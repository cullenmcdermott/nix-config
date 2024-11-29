{
  pkgs,
  lib,
  config,
  username,
  ...
}:
let
in
{
  programs.zsh.enable = true;
  environment.shells = [
    pkgs.zsh
    pkgs.bash
  ];
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    extra-trusted-substituters = https://cache.flox.dev
    extra-trusted-public-keys = flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=
  '';
  environment.systemPackages = [
    pkgs.coreutils
  ];
  system.activationScripts.postUserActivation.text = ''
    apps_source="${config.system.build.applications}/Applications"
    moniker="Nix Trampolines"
    app_target_base="$HOME/Applications"
    app_target="$app_target_base/$moniker"
    mkdir -p "$app_target"
    ${pkgs.rsync}/bin/rsync --archive --checksum --chmod=-w --copy-unsafe-links --delete "$apps_source/" "$app_target"
  '';
  system.keyboard.enableKeyMapping = true;
  fonts.packages = [ (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];
  services.nix-daemon.enable = true;
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder._FXShowPosixPathInTitle = false;
  system.defaults.trackpad.TrackpadThreeFingerDrag = true;
  system.defaults.dock.orientation = "left";
  system.defaults.dock.autohide = true;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 14;
  system.defaults.NSGlobalDomain.KeyRepeat = 2;
  system.stateVersion = 4;
  homebrew = {
    enable = true;
    caskArgs.no_quarantine = true;
    global.brewfile = true;
    masApps = { };
    taps = [
      "depot/tap"
    ];
    brews = [
      "colima"
    ];
    casks = [
      # install via homebrew
      # https://github.com/NixOS/nixpkgs/issues/254944
      "1password"
      "arc"
      "caffeine"
      "discord"
      "firefox"
      "philips-hue-sync"
      "hiddenbar"
      "istat-menus"
      "slack"
      "visual-studio-code"
    ];
  };
}
