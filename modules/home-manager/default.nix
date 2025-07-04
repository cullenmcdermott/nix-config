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


in
{
  # specify home-manager configs
  imports = [
    ./nvim
  ];
  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    _1password-cli
    aerospace
    alejandra
    attic-client
    argc
    cargo
    chart-testing
    claude-code
    colima
    curl
    deadnix
    devpod
    docker
    docker-compose
    fd
    gdk
    gh
    gopls
    go
    jq
    just
    k3d
    k9s
    krew
    kubecolor
    kubectl
    kubernetes-helm
    kubevirt
    kubie
    kubelogin-oidc
    less
    luajitPackages.lua-lsp
    lima
    nixd
    nixfmt-rfc-style
    nodejs
    omnictl
    packer
    pipx
    playwright-driver
    pyright
    qemu
    renovate
    ripgrep
    silver-searcher
    skopeo
    statix
    tailscale
    talosctl
    terraform
    terraform-ls
    tflint
    unixtools.watch
    unzip
    uv
    wget
    xdg-utils
    xdg-user-dirs
  ];
  xdg = {
    enable = true;
    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
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
  home.homeDirectory = lib.mkForce "/Users/${username}";
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = "/Users/${username}";
    TERM = "xterm";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
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
  
  # Install claude-monitor and ccusage
  home.activation.installClaudeTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
    export PATH="${pkgs.uv}/bin:${pkgs.nodejs}/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.uv}/bin/uv tool install claude-monitor --force
    # Install ccusage to user's home directory
    $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install --prefix ~/.local ccusage
  '';
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
