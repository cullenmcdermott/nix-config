{
  config,
  pkgs,
  lib,
  username,
  ...
}:
let
  homeDirectory =
    if pkgs.stdenv.isDarwin then
      "/Users/${username}"
    else
      "/home/${username}";
in
{
  xdg = {
    enable = true;
    cacheHome = "${homeDirectory}/.cache";
    configHome = "${homeDirectory}/.config";
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
        "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
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
  programs.zsh.initContent = lib.mkBefore ''
    ${builtins.readFile ./dotfiles/zshrc}
  '';
  programs.zsh.shellAliases = {
    brew = "op plugin run -- brew";
    ls = "ls --color=auto -F";
    vim = "nvim";
    nixswitch = "sudo darwin-rebuild switch --flake ~/src/system-config/.#";
    nixup = "pushd ~/src/system-config && nix flake update && sudo darwin-rebuild switch --flake ~/src/system-config/.#; popd";
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
  };
  programs.zsh.plugins = [ ];
  programs.zsh.oh-my-zsh.enable = false;
  programs.direnv.enable = true;
  programs.direnv.package = pkgs.direnv.overrideAttrs (_: { doCheck = false; });
  programs.starship.enable = true;
  programs.starship.enableZshIntegration = true;

  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = homeDirectory;
    TERM = "xterm";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/node_modules/.bin"
  ];
}
