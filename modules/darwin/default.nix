{ pkgs, ...}: {
  programs.zsh.enable = true;
  environment.shells =  [ pkgs.zsh pkgs.bash ];
  environment.loginShell = pkgs.zsh;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  environment.systemPackages = [
    pkgs.coreutils
  ];
  system.keyboard.enableKeyMapping = true;
  fonts.fontDir.enable = false; # won't overwrite existing installed fonts
  fonts.fonts = [ (pkgs.nerdfonts.override {
      fonts = [ "JetBrainsMono"];
  }) ];
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
    masApps = {};
    brews = [
      "colima"
      "docker"
      "lima"
    ];
    casks = [ 
      #"arc"
      "caffeine"
      "discord"
      #"istat-menus"
      "firefox"
      "hiddenbar"
      "raycast"
      "shureplus-motiv"
      "slack"
      "visual-studio-code"
    ];
  };
}

