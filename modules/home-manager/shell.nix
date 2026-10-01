{
  config,
  pkgs,
  lib,
  ...
}:
{
  xdg = {
    enable = true;
    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    configFile."ghostty/config" = {
      text = ''
        theme = TokyoNight Storm
        font-family = JetBrainsMono Nerd Font
        font-style = medium
        font-size = 14
        macos-titlebar-style = tabs
        background-opacity = 0.90
        background-blur-radius = 10
        window-padding-x = 10
        window-padding-y = 10
        keybind = super+shift+h=previous_tab
        keybind = super+shift+l=next_tab
        keybind = super+shift+r=reload_config
        keybind = shift+enter=text:\x1b\r
        scrollback-limit = 2147483648
      '';
    };
    configFile."cmux/settings.json" = lib.mkIf pkgs.stdenv.isDarwin {
      text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
        app = {
          appearance = "dark";
          sendAnonymousTelemetry = false;
        };
        browser.theme = "dark";
        shortcuts.bindings = {
          focusLeft = "ctrl+shift+h";
          focusDown = "ctrl+shift+j";
          focusUp = "ctrl+shift+k";
          focusRight = "ctrl+shift+l";
          prevSurface = "cmd+shift+j";
          nextSurface = "cmd+shift+k";
          reloadConfiguration = "cmd+shift+r";
        };
      };
    };
  };

  programs.bat.enable = true;
  programs.bat.config.theme = "TwoDark";
  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;
  programs.zsh.enable = true;
  programs.zsh.dotDir = "${config.xdg.configHome}/zsh";
  programs.zsh.enableCompletion = true;
  programs.zsh.autosuggestion.enable = true;
  programs.zsh.history = {
    size = 10000000;
    save = 10000000;
    path = "${config.xdg.dataHome}/zsh/history";
    extended = true;
    share = true;
    append = true;
  };
  programs.zsh.syntaxHighlighting.enable = true;
  # Normal (mkOrder 1000) priority: home-manager emits this *after* its own
  # `autoload -U compinit && compinit`, which the compdef calls in the file
  # require. lib.mkBefore placed it above compinit, where compdef is undefined.
  programs.zsh.initContent = builtins.readFile ./dotfiles/zshrc;
  # Single-user Nix installs (the distrobox container) only put the profile on
  # PATH via nix.sh. home-manager owns ~/.zshenv, so source it from envExtra
  # rather than appending to a Nix-managed rc file. No-op when the file is
  # absent (NixOS / multi-user installs).
  programs.zsh.envExtra = lib.optionalString pkgs.stdenv.isLinux ''
    if [[ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]]; then
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
  '';
  programs.zsh.shellAliases = {
    cdx = "codex";
    fixdns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
    ls = "ls --color=auto -F";
    vim = "nvim";
    k = "kubecolor";
    ga = "git add";
    gb = "git branch";
    gbD = "git branch -D";
    gc = "git commit -v";
    gcma = "git checkout main";
    gco = "git checkout";
    gcb = "git checkout -b";
    gd = "git diff";
    gl = "git pull";
    glola = "git log --graph --pretty='''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset''' --all";
    gm = "git merge";
    gp = "git push";
    grb = "git rebase";
    gst = "git status";
    gcl = "git clone";
    grv = "git remote -v";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # 1Password shell plugins, Homebrew and darwin-rebuild are macOS-only; the
    # Linux hosts switch with `home-manager switch --flake <repo>#<name>`.
    brew = "op plugin run -- brew";
    nixswitch = "sudo darwin-rebuild switch --flake ~/src/system-config/.#";
    nixup = "pushd ~/src/system-config && nix flake update && sudo darwin-rebuild switch --flake ~/src/system-config/.#; popd";
  };
  programs.zsh.plugins = [ ];
  programs.zsh.oh-my-zsh.enable = false;
  programs.direnv.enable = true;
  programs.direnv.package = pkgs.direnv.overrideAttrs (_: {
    doCheck = false;
  });
  programs.starship.enable = true;
  programs.starship.enableZshIntegration = true;

  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    # Graphical askpass for ssh/git prompts on the Linux boxes (Plasma) and in
    # the distrobox container. Absolute store path so it resolves before the
    # profile is on PATH; the package itself is in dev-packages.nix.
    SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    GIT_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/node_modules/.bin"
  ];
}
