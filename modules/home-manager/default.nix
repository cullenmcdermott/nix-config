{config, lib, pkgs, ...}: 
let
  gdk = pkgs.google-cloud-sdk.withExtraComponents( with pkgs.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
in
{
  # specify home-manager configs
  home.stateVersion = "24.11";
  home.packages = with pkgs; [ 
    gdk
    curl
    chart-testing
    devpod
    docker
    fd
    gopls
    k9s
    kubecolor
    kubectl
    less 
    lima
    ripgrep
    terraform
    packer
    terraform-ls
    tflint
  ];
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = "/Users/cullen";
    TERM = "xterm";
  };
  programs.neovim = {
    # From https://github.com/LazyVim/LazyVim/discussions/1972
    enable = true;
    extraPackages = with pkgs; [
      # LazyVim
      lua-language-server
      stylua
      # Telescope
      ripgrep
    ];
    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];

    extraLuaConfig =
      let
        plugins = with pkgs.vimPlugins; [
          # LazyVim
          LazyVim
          bufferline-nvim
          cmp-buffer
          cmp-nvim-lsp
          cmp-path
          cmp_luasnip
          conform-nvim
          dashboard-nvim
          dressing-nvim
          flash-nvim
          friendly-snippets
          gitsigns-nvim
          indent-blankline-nvim
          lualine-nvim
          neo-tree-nvim
          neoconf-nvim
          neodev-nvim
          noice-nvim
          nui-nvim
          nvim-cmp
          nvim-lint
          nvim-lspconfig
          nvim-notify
          nvim-spectre
          nvim-treesitter
          nvim-treesitter-context
          nvim-treesitter-textobjects
          nvim-ts-autotag
          nvim-ts-context-commentstring
          nvim-web-devicons
          persistence-nvim
          plenary-nvim
          telescope-fzf-native-nvim
          telescope-nvim
          todo-comments-nvim
          tokyonight-nvim
          trouble-nvim
          vim-illuminate
          vim-startuptime
          which-key-nvim
          { name = "LuaSnip"; path = luasnip; }
          { name = "catppuccin"; path = catppuccin-nvim; }
          { name = "mini.ai"; path = mini-nvim; }
          { name = "mini.bufremove"; path = mini-nvim; }
          { name = "mini.comment"; path = mini-nvim; }
          { name = "mini.indentscope"; path = mini-nvim; }
          { name = "mini.pairs"; path = mini-nvim; }
          { name = "mini.surround"; path = mini-nvim; }
        ];
        mkEntryFromDrv = drv:
          if lib.isDerivation drv then
            { name = "${lib.getName drv}"; path = drv; }
          else
            drv;
        lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins);
      in
      ''
        require("lazy").setup({
          defaults = {
            lazy = true,
          },
          dev = {
            -- reuse files from pkgs.vimPlugins.*
            path = "${lazyPath}",
            patterns = { "." },
            -- fallback to download
            fallback = true,
          },
          spec = {
            { "LazyVim/LazyVim", import = "lazyvim.plugins" },
            -- The following configs are needed for fixing lazyvim on nix
            -- force enable telescope-fzf-native.nvim
            { "nvim-telescope/telescope-fzf-native.nvim", enabled = true },
            -- disable mason.nvim, use programs.neovim.extraPackages
            { "williamboman/mason-lspconfig.nvim", enabled = false },
            { "williamboman/mason.nvim", enabled = false },
            -- import/override with your plugins
            { import = "plugins" },
            -- treesitter handled by xdg.configFile."nvim/parser", put this line at the end of spec to clear ensure_installed
            { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
          },
        })
      '';
  };

  # https://github.com/nvim-treesitter/nvim-treesitter#i-get-query-error-invalid-node-type-at-position
  xdg.configFile."nvim/parser".source =
    let
      parsers = pkgs.symlinkJoin {
        name = "treesitter-parsers";
        paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins: with plugins; [
          c
          lua
        ])).dependencies;
      };
    in
    "${parsers}/parser";

  # Normal LazyVim config here, see https://github.com/LazyVim/starter/tree/main/lua
  xdg.configFile."nvim/lua".source = ./lua;
  xdg.configFile."nvim/lua/lazy.lua".source = ./lua/lazy.lua;

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
    cat = "bat";
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
}

