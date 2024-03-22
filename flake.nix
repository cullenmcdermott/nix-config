{
  description = "cullen's mbp flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    #nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
 
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: {
    darwinConfigurations.cmcdermott-mbp = inputs.darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = import inputs.nixpkgs { system = "aarch64-darwin"; };
      modules = [
        ({ pkgs, ...}: {
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
        })

        inputs.home-manager.darwinModules.home-manager {
          users.users.cullen.home = "/Users/cullen";
          home-manager = { 
            useGlobalPkgs = true;
            useUserPackages = true;
            users.cullen.imports = [
              ({pkgs, ...}: {
                # specify home-manager configs
                home.stateVersion = "24.05";
                home.packages = [ pkgs.ripgrep pkgs.fd pkgs.curl pkgs.less ];
                home.sessionVariables = {
                  PAGER = "less";
                  EDITOR = "nvim";
                  HOME = "/Users/cullen";
                };
                programs.bat.enable = true;
                programs.bat.config.theme = "TwoDark";
                programs.fzf.enable = true;
                programs.fzf.enableZshIntegration = true;
                programs.zsh.enable = true;
                programs.zsh.enableCompletion = true;
                programs.zsh.autosuggestion.enable = true;
                programs.zsh.syntaxHighlighting.enable = true;
                programs.zsh.shellAliases = {
                  ls = "ls --color=auto -F";
                  vim = "nvim";
                };
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
              })
            ];
          };
        }
      ];
    };
  };
}
