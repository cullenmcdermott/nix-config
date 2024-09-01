{
  config,
  pkgs,
  inputs,
  ...
}: let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
in {
  # specify home-manager configs
  imports = [./nvim];
  home.stateVersion = "24.05";
  home.packages = with pkgs; [
    alejandra
    cargo
    curl
    chart-testing
    deadnix
    devpod
    docker
    fd
    gdk
    gopls
    k9s
    krew
    kubecolor
    kubectl
    kubevirt
    kubie
    less
    luajitPackages.lua-lsp
    lima
    nixfmt-rfc-style
    packer
    pipx
    renovate
    ripgrep
    skopeo
    statix
    terraform
    terraform-ls
    tflint
    xdg-utils # provides cli tools such as `xdg-mime` `xdg-open`
    xdg-user-dirs
    pipx
  ];
  home.activation = {
    installAiderChat = config.lib.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.pipx}/bin/pipx install aider-chat
    '';
  };
  xdg = {
    enable = true;
    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
  };
  home.homeDirectory = "/Users/cullen";
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = "/Users/cullen";
    TERM = "xterm";
    GOPRIVATE="github.com/octoml";
  };
  # home.file."./.config/nvim/" = {
  #   source = ../programs/neovim/nvim;
  #   recursive = true;
  # };
  programs.bat.enable = true;
  programs.bat.config.theme = "TwoDark";
  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;
  programs.zsh.enable = true;
  programs.zsh.enableCompletion = true;
  programs.zsh.autosuggestion.enable = true;
  programs.zsh.syntaxHighlighting.enable = true;
  programs.zsh.initExtra = ''
    ${builtins.readFile ./dotfiles/zshrc}
  '';
  programs.zsh.shellAliases = {
    ls = "ls --color=auto -F";
    vim = "nvim";
    ssh = "kitty +kitten ssh";
    nixswitch = "darwin-rebuild switch --flake ~/src/system-config/.#";
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
  programs.zsh.oh-my-zsh.enable = true;
  programs.zsh.oh-my-zsh.plugins = ["git" "direnv"];
  programs.direnv.enable = true;
  programs.granted.enable = true;
  programs.granted.enableZshIntegration = true;
  programs.starship.enable = true;
  programs.starship.enableZshIntegration = true;
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono";
      size = 14;
    };
    theme = "Tokyo Night";
    keybindings = {
      "ctrl+shift+'" = "launch --location=vsplit";
      "ctrl+shift+5" = "launch --location=hsplit";
      "ctrl+shift+h" = "neighboring_window left";
      "ctrl+shift+l" = "neighboring_window right";
      "ctrl+shift+k" = "neighboring_window up";
      "ctrl+shift+j" = "neighboring_window down";
      "ctrl+shift+o" = "layout_action rotate";
      "ctrl+alt+left" = "resize_window narrower";
      "ctrl+alt+right" = "resize_window wider";
      "ctrl+alt+up" = "resize_window taller";
      "ctrl+alt+down" = "resize_window shorter 3";
      "ctrl+shift+f" = "show_scrollback";
      "ctrl+left" = "no_op";
      "ctrl+right" = "no_op";
    };
    settings = {
      confirm_os_window_close = -0;
      copy_on_select = true;
      clipboard_control = "write-clipboard read-clipboard write-primary read-primary";
      enabled_layouts = "splits";
      scrollback_lines = 200000;
      tab_bar_style = "powerline";
      tab_activity_symbol = "*";
      tab_title_template = "{activity_symbol}{title}{activity_symbol}";
    };
  };
}
