{pkgs, ...}: {
  # specify home-manager configs
  home.stateVersion = "24.05";
  home.packages = [ pkgs.ripgrep pkgs.fd pkgs.curl pkgs.less ];
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = "/Users/cullen";
    TERM = "xterm";
  };
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
    gcma = "git checkout main";
    ssh = "kitty +kitten ssh";
    nixswitch = "darwin-rebuild switch --flake ~/src/system-config/.#";
    nixup = "pushd ~/src/system-config; nix flake update; nixswitch; popd";
  };
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
  programs.kitty = {
    enable = true;
    font.name = "JetBrainsMono Nerd Font";
    theme = "Tokyo Night";
    settings = {
    	confirm_os_window_close = -0;
    	copy_on_select = true;
    	clipboard_control = "write-clipboard read-clipboard write-primary read-primary";
    };
  };
}

