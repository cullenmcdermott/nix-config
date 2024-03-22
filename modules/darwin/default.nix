{ pkgs, ...}: {
  # here go the darwin prefs and config
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
  system.defaults.finder._FXShowPosixPathInTitle = true;
  system.defaults.dock.autohide = true;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 14;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.stateVersion = 4;
  homebrew = {
    enable = true;
    caskArgs.no_quarantine = true;
    global.brewfile = true;
    masApps = {};
    casks = [ "raycast" ];
  };
}

