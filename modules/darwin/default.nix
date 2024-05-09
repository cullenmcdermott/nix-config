{ pkgs, ...}: {
  programs.zsh.enable = true;
  environment.shells =  [ pkgs.zsh pkgs.bash ];
  environment.loginShell = pkgs.zsh;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    extra-trusted-substituters = https://cache.flox.dev
    extra-trusted-public-keys = flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=
  '';
  environment.systemPackages = [
    pkgs.coreutils
    pkgs.neovim
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
      "devcontainer"
    ];
    casks = [ 
      "arc"
      "caffeine"
      "discord"
      "firefox"
      "hiddenbar"
      "istat-menus"
      "raycast"
      "shureplus-motiv"
      "slack"
      "visual-studio-code"
    ];
  };
}

