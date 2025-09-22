{
  config,
  pkgs,
  lib,
  username,
  inputs,
  ...
}:
let
  # pkgs is already unstable now

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

  # Import MCP server packages
  mcpServers = import ./mcp-servers.nix { inherit pkgs inputs lib; };

in
{
  # specify home-manager configs
  imports = [
    ./nvim
    ./packages
    ./claude-code.nix
  ];
  home.stateVersion = "24.05";
  home.packages =
    with pkgs; # All packages are unstable now
    [
      # Core packages available on all platforms
      alejandra
      argc
      argocd
      cargo
      chart-testing
      google-chrome
      claude-code
      curl
      deadnix
      devpod
      docker
      docker-compose
      fd
      flyctl
      gdk
      gh
      git
      gopls
      go
      jq
      just
      k9s
      kubie
      kubecolor
      kubectl
      kubelogin-oidc
      kubernetes-helm
      krew
      less
      luajitPackages.lua-lsp
      nixd
      nixfmt-rfc-style
      nodejs
      omnictl
      packer
      pipx
      pyright
      renovate
      ripgrep
      silver-searcher
      skopeo
      statix
      talosctl
      tailscale
      terraform
      terraform-ls
      tflint
      unzip
      uv
      unixtools.watch
      wget
      # MCP Servers - installed via Nix for reproducibility
      mcpServers.context7-mcp
      mcpServers.serena
      playwright-mcp # From nixpkgs
      playwright-driver # Playwright browser driver
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # macOS-specific packages
      _1password-cli
      aerospace
      colima
      lima
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Essential Linux packages for distrobox environment
      kdePackages.ksshaskpass
      obs-studio
      vlc
      k3d
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
    nixup = "pushd ~/src/system-config && nix flake update --accept-flake-config && sudo darwin-rebuild switch --flake ~/src/system-config/.#; popd";
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
    clod = "claude --mcp-config ~/.claude/mcp.json";
  };

  programs.zsh.plugins = [ ];
  programs.zsh.oh-my-zsh.enable = false;
  programs.direnv.enable = true;
  programs.starship.enable = true;
  programs.starship.enableZshIntegration = true;
}
