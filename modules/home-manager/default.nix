{config, pkgs, inputs, ...}:
let
  neovimconfig = import ../programs/neovim;
  nvim = inputs.nixvim.legacyPackages.x86_64-linux.makeNixvimWithModule {
    inherit pkgs;
    module = neovimconfig;
  };
in
{
  # specify home-manager configs
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
  ];
  home.stateVersion = "24.05";
  home.packages = with pkgs; [ 
    ripgrep
    fd
    curl
    less 
    terraform
    gopls
    terraform-ls
    tflint
    devpod
    nvim
  ];
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = "/Users/cullen";
    TERM = "xterm";
  };
  home.file."./.config/nvim/" = {
    source = ../programs/neovim/nvim;
    recursive = true;
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
    ssh = "kitty +kitten ssh";
    nixswitch = "darwin-rebuild switch --flake ~/src/system-config/.#";
    nixup = "pushd ~/src/system-config; nix flake update; nixswitch; popd";
    k    = "kubecolor";
    ga   = "git add";
    gb   = "git branch";
    gbD  = "git branch -D";
    gc   = "git commit -v";
    gcma = "git checkout main";
    gco  = "git checkout";
    gcb  = "git checkout -b";
    gd   = "git diff";
    gl   = "git pull";
    glola= "git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'\'' --all";
    gm   = "git merge";
    gp   = "git push";
    grb  = "git rebase";
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
      "ctrl+left"  = "no_op";
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

  #programs.nixvim = {
  #  enable = true;
  #  keymaps = [
  #    # Equivalent to nnoremap ; :
  #    {
  #      key = ";";
  #      action = ":";
  #    }

  #    # Equivalent to nmap <silent> <buffer> <leader>gg <cmd>Man<CR>
  #    {
  #      key = "<leader>gg";
  #      action = "<cmd>Man<CR>";
  #      options = {
  #        silent = true;
  #        remap = false;
  #      };
  #    }
  #    # Etc...
  #  ];

  #  # We can set the leader key:
  #  globals.mapleader = ",";

  #  # We can create maps for every mode!
  #  # There is .normal, .insert, .visual, .operator, etc!

  #  # We can also set options:
  #  options = {
  #    tabstop = 4;
  #    shiftwidth = 4;
  #    expandtab = false;

  #    mouse = "a";

  #    # etc...
  #  };

  #  # Of course, we can still use comfy vimscript:
  #  #extraConfigVim = builtins.readFile ./init.vim;
  #  ## Or lua!
  #  #extraConfigLua = builtins.readFile ./init.lua;

  #  # One of the big advantages of NixVim is how it provides modules for
  #  # popular vim plugins
  #  # Enabling a plugin this way skips all the boring configuration that
  #  # some plugins tend to require.
  #  plugins = {

  #    lightline = {
  #      enable = true;

  #      # This is optional - it will default to your enabled colorscheme
  #      colorscheme = "wombat";

  #      # This is one of lightline's example configurations
  #      active = {
  #        left = [
  #          ["mode" "paste"]
  #          ["readonly" "filename" "modified" "helloworld"]
  #        ];
  #      };

  #      component = {
  #        helloworld = "Hello, world!";
  #      };
  #    };

  #    # Of course, there are a lot more plugins available.
  #    # You can find an up-to-date list here:
  #    # https://nixvim.pta2002.com/plugins
  #  };

  #  # There is a separate namespace for colorschemes:
  #  colorschemes.gruvbox.enable = true;

  #  # What about plugins not available as a module?
  #  # Use extraPlugins:
  #  #extraPlugins = with pkgs.vimPlugins; [vim-toml];
  #};
}

