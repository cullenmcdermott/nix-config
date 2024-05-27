{
  pkgs,
  lib,
  ...
}: {
  config = {
    plugins = {
      #none-ls = {
      #  enable = true;
      #  enableLspFormat = true;
      #  updateInInsert = false;
      #  sources = {
      #    code_actions = {
      #      gitsigns.enable = true;
      #      statix.enable = true;
      #    };
      #    diagnostics = {
      #      statix.enable = true;
      #      yamllint.enable = false;
      #    };
      #    formatting = {
      #      alejandra.enable = true;
      #      black = {
      #        enable = true;
      #        withArgs = ''
      #          {
      #            extra_args = { "--fast" },
      #          }
      #        '';
      #      };
      #      prettier = {
      #        enable = true;
      #        disableTsServerFormatter = true;
      #        withArgs = ''
      #          {
      #            extra_args = { "--no-semi", "--single-quote" },
      #          }
      #        '';
      #      };
      #      stylua.enable = true;
      #      #yamlfmt.enable = true;
      #    };
      #  };
      #};
      cmp-buffer = {enable = true;};
      cmp-path = {enable = true;};
      cmp-nvim-lsp = {enable = true;};
      cmp_luasnip = {enable = true;};
      cmp-cmdline = {enable = true;};
      copilot-cmp = {enable = true;};
      copilot-lua = {
        enable = true;
        suggestion = {enabled = false;};
        panel = {enabled = false;};
      };

      flash = {enable = true;};
      illuminate = {
        enable = true;
        delay = 200;
        largeFileCutoff = 2000;
        largeFileOverrides = {providers = ["lsp"];};
      };
      lint = {enable = true;};
      luasnip = {
        enable = true;
        extraConfig = {
          enable_autosnippets = true;
          store_selection_keys = "<Tab>";
        };
        fromVscode = [
          {
            lazyLoad = true;
            paths = "${pkgs.vimPlugins.friendly-snippets}";
          }
        ];
      };
      friendly-snippets = {enable = true;};
      nvim-autopairs = {enable = true;};
      ts-context-commentstring = {enable = true;};
      ts-autotag = {enable = true;};
      treesitter = {enable = true;};
      treesitter-textobjects = {enable = true;};
      treesitter-context = {enable = true;};
      trouble = {
        enable = true;
        settings = {
          auto_close = true;
          use_lsp_diagnostic_signs = true;
        };
      };
      todo-comments = {enable = true;};
      which-key = {enable = true;};

      neo-tree = {
        enable = true;
        filesystem = {
          bindToCwd = false;
          followCurrentFile = {enabled = true;};
        };
      };
    };
  };
}
#{ pkgs, nixvim, ... }: {
#  let
#    system = "x86_64-darwin";
#  in
#  environment.systemModules = [
#    (nixvim.legacyPackages."${system}".makeNixvim {
#      colorschemes.gruvbox.enable = true;
#    })
#  ];
#}
#{ pkgs, ... }:
#let
#  treesitterWithGrammars = (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
#    p.bash
#    p.comment
#    p.dockerfile
#    p.gitattributes
#    p.gitignore
#    p.go
#    p.gomod
#    p.gowork
#    p.hcl
#    p.javascript
#    p.jq
#    p.json5
#    p.json
#    p.lua
#    p.make
#    p.markdown
#    p.python
#    p.toml
#    p.typescript
#    p.vue
#    p.yaml
#  ]));
#in
#{
#  home.packages = with pkgs; [
#    ripgrep
#    fd
#    fzf
#    terraform-ls
#    lua-language-server
#    black
#  ];
#
#  programs.neovim = {
#    enable = true;
#    globals.mapleader = "^";
#    colorschemes.gruvbox.enable = true;
#
#    plugins = {};
#  };
#}
#

