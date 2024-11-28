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
  system.activationScripts.applications.text = lib.mkForce ''
    echo "setting up ~/Applications..." >&2
    applications="$HOME/Applications"
    nix_apps="$applications/Nix Apps"
    # Needs to be writable by the user so that home-manager can symlink into it
    if ! test -d "$applications"; then
        mkdir -p "$applications"
        chown ${username}: "$applications"
        chmod u+w "$applications"
    fi
    # Delete the directory to remove old links
    rm -rf "$nix_apps"
    mkdir -p "$nix_apps"
    find ${config.system.build.applications}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read -r src; do
            # Spotlight does not recognize symlinks, it will ignore directory we link to the applications folder.
            # It does understand MacOS aliases though, a unique filesystem feature. Sadly they cannot be created
            # from bash (as far as I know), so we use the oh-so-great Apple Script instead.
            /usr/bin/osascript -e "
                set fileToAlias to POSIX file \"$src\"
                set applicationsFolder to POSIX file \"$nix_apps\"
                tell application \"Finder\"
                    make alias file to fileToAlias at applicationsFolder
                    # This renames the alias; 'mpv.app alias' -> 'mpv.app'
                    set name of result to \"$(/usr/bin/rev <<< "$src" | cut -d'/' -f1 | /usr/bin/rev)\"
                end tell
            " 1>/dev/null
        done
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
      "chart-testing"
      "colima"
      "coreutils"
      "depot"
      "docker"
      "kubecolor"
      "lima"
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
      "raycast"
      "slack"
      "visual-studio-code"
    ];
  };
}
