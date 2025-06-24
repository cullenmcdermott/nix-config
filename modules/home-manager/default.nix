{
  config,
  pkgs,
  lib,
  username,
  ...
}:
let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      gke-gcloud-auth-plugin
    ]
  );

  # Platform detection - enables cross-platform compatibility
  homeDirectory =
    if pkgs.stdenv.isDarwin then
      "/Users/${username}" # macOS - same as before
    else
      "/home/${username}"; # Linux - for future NixOS support

in
{
  # specify home-manager configs
  imports = [
    ./nvim
    ./packages
  ];
  home.stateVersion = "24.05";
  home.packages =
    with pkgs;
    [
      # Core packages available on all platforms
      alejandra
      argc
      cargo
      curl
      deadnix
      fd
      gdk
      gh
      gopls
      go
      jq
      just
      k9s
      kubecolor
      kubectl
      kubernetes-helm
      less
      luajitPackages.lua-lsp
      nixd
      nixfmt-rfc-style
      nodejs
      pipx
      #playwright-driver
      pyright
      renovate
      ripgrep
      silver-searcher
      statix
      tailscale
      terraform
      terraform-ls
      tflint
      unzip
      uv
      wget
      xdg-utils
      xdg-user-dirs
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # macOS-specific packages
      _1password-cli
      aerospace
      colima
      docker
      docker-compose
      lima
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Linux-specific packages
      docker
      docker-compose
      ghostty
      # Add other Linux-specific tools here
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Kubernetes tools that might have platform differences
      attic-client
      chart-testing
      claude-code
      devpod
      k3d
      krew
      kubevirt
      kubie
      kubelogin-oidc
      omnictl
      packer
      qemu
      skopeo
      talosctl
      unixtools.watch
    ];
  xdg = {
    enable = true;
    cacheHome = "${homeDirectory}/.cache";
    configHome = "${homeDirectory}/.config";
    configFile."ghostty/config" = {
      text = ''
        theme = tokyonight-storm
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
  };
  home.homeDirectory = lib.mkForce homeDirectory;
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = homeDirectory;
    TERM = "xterm";
    #PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/node_modules/.bin"
  ];
  programs.bat.enable = true;
  programs.bat.config.theme = "TwoDark";
  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;
  programs.zsh.enable = true;
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
  programs.zsh.initContent = ''
    ${builtins.readFile ./dotfiles/zshrc}
  '';
  programs.zsh.shellAliases = {
    brew = "op plugin run -- brew";
    ls = "ls --color=auto -F";
    vim = "nvim";
    nixswitch = "sudo darwin-rebuild switch --flake ~/src/system-config/.#";
    nixup = "pushd ~/src/system-config; nix flake update; nixswitch; popd";
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
  };

  programs.zsh.plugins = [ ];
  programs.zsh.oh-my-zsh.enable = true;
  programs.zsh.oh-my-zsh.plugins = [
    "git"
    "direnv"
  ];
  programs.direnv.enable = true;
  programs.granted.enable = true;
  programs.granted.enableZshIntegration = true;
  programs.starship.enable = true;
  programs.starship.enableZshIntegration = true;
  #programs.kitty = {
  #  enable = true;
  #  font = {
  #    name = "JetBrainsMono";
  #    size = 14;
  #  };
  #  themeFile = "tokyo_night_storm";
  #  keybindings = {
  #    "ctrl+shift+'" = "launch --location=vsplit";
  #    "ctrl+shift+5" = "launch --location=hsplit";
  #    "ctrl+shift+h" = "neighboring_window left";
  #    "ctrl+shift+l" = "neighboring_window right";
  #    "ctrl+shift+k" = "neighboring_window up";
  #    "ctrl+shift+j" = "neighboring_window down";
  #    "ctrl+shift+o" = "layout_action rotate";
  #    "ctrl+alt+left" = "resize_window narrower";
  #    "ctrl+alt+right" = "resize_window wider";
  #    "ctrl+alt+up" = "resize_window taller";
  #    "ctrl+alt+down" = "resize_window shorter 3";
  #    "ctrl+shift+f" = "show_scrollback";
  #    "ctrl+left" = "no_op";
  #    "ctrl+right" = "no_op";
  #  };
  #  settings = {
  #    confirm_os_window_close = -0;
  #    copy_on_select = true;
  #    clipboard_control = "write-clipboard read-clipboard write-primary read-primary";
  #    enabled_layouts = "splits";
  #    scrollback_lines = 200000;
  #    tab_bar_style = "powerline";
  #    tab_activity_symbol = "*";
  #    tab_title_template = "{activity_symbol}{title}{activity_symbol}";
  #  };
  #};
}
