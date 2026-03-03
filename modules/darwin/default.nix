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
  # Allow unsupported packages temporarily
  nixpkgs.config.allowUnsupportedSystem = true;
  # Chrome updater is broken in nixpkgs - allow until fixed
  nixpkgs.config.permittedInsecurePackages = [
    "google-chrome-144.0.7559.97"
  ];

  system.primaryUser = username;

  # Make user trusted for Nix daemon
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
  system.activationScripts.extraActivation.text = ''
    apps_source="${config.system.build.applications}/Applications"
    echo "apps source is $apps_source"
    moniker="Nix Trampolines"
    app_target_base="$HOME/Applications"
    app_target="$app_target_base/$moniker"
    mkdir -p "$app_target"
    ${pkgs.rsync}/bin/rsync --verbose --archive --checksum --chmod=-w --copy-unsafe-links --delete "$apps_source/" "$app_target"
  '';
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
  # Nix garbage collection — runs multiple times per week so a missed window
  # (laptop asleep) doesn't mean waiting a full week.
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  # Override the single launchd interval with multiple start times:
  # Mon/Wed/Fri/Sun at 10:00 and 12:00 to maximise chance of catching the laptop awake.
  launchd.daemons.nix-gc.serviceConfig.StartCalendarInterval = [
    { Weekday = 1; Hour = 10; Minute = 0; }
    { Weekday = 1; Hour = 12; Minute = 0; }
    { Weekday = 3; Hour = 10; Minute = 0; }
    { Weekday = 3; Hour = 12; Minute = 0; }
    { Weekday = 5; Hour = 10; Minute = 0; }
    { Weekday = 5; Hour = 12; Minute = 0; }
    { Weekday = 0; Hour = 10; Minute = 0; }
    { Weekday = 0; Hour = 12; Minute = 0; }
  ];

  system.stateVersion = 6;
  homebrew = {
    enable = true;
    caskArgs.no_quarantine = true;
    global.brewfile = true;
    masApps = { };
    casks = [
      # install via homebrew
      # https://github.com/NixOS/nixpkgs/issues/254944
      "1password"
      "arc"
      "caffeine"
      "discord"
      "firefox"
      "karabiner-elements"  # Requires privileged daemons, can't use nixpkgs version
      "philips-hue-sync"
      "hiddenbar"
      "istat-menus"
      "slack"
    ];
  };
}
