{ pkgs, lib, ... }: {
  config = {
    globals = { mapleader = " "; };

    keymaps = [
      {
        mode = "n";
        key = "<leader>f";
        action = "+find/file";
      }
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-W>h";
        options = {
          silent = true;
          desc = "Move to window left";
        };
      }

      {
        mode = "n";
        key = "<C-l>";
        action = "<C-W>l";
        options = {
          silent = true;
          desc = "Move to window right";
        };
      }

      {
        mode = "n";
        key = "<C-k>";
        action = "<C-W>k";
        options = {
          silent = true;
          desc = "Move to window above";
        };
      }

      {
        mode = "n";
        key = "<C-j>";
        action = "<C-W>j";
        options = {
          silent = true;
          desc = "Move to window below";
        };
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "neotree";
        options = {
          silent = true;
          desc = "Jump to neotree";
        };
      }
    ];
    # General maps
    colorschemes = {
      tokyonight.enable = true;
      tokyonight.settings = {
        style = "storm";
        light_style = "day";
        transparent = false;
        terminal_colors = true;
        styles = {
          comments.italic = true;
          keywords.italic = true;
          functions = { };
          variables = { };
          sidebars = "dark";
          floats = "dark";
        };
      };
    };
    extraConfigLua = ''
          luasnip = require("luasnip")
          kind_icons = {
            Text = "󰊄",
            Method = "",
            Function = "󰡱",
            Constructor = "",
            Field = "",
            Variable = "󱀍",
            Class = "",
            Interface = "",
            Module = "󰕳",
            Property = "",
            Unit = "",
            Value = "",
            Enum = "",
            Keyword = "",
            Snippet = "",
            Color = "",
            File = "",
            Reference = "",
            Folder = "",
            EnumMember = "",
            Constant = "",
            Struct = "",
            Event = "",
            Operator = "",
            TypeParameter = "",
          }

           local cmp = require'cmp'

       -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
       cmp.setup.cmdline({'/', "?" }, {
         sources = {
           { name = 'buffer' }
         }
       })

      -- Set configuration for specific filetype.
       cmp.setup.filetype('gitcommit', {
         sources = cmp.config.sources({
           { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
         }, {
           { name = 'buffer' },
         })
       })

       -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
       cmp.setup.cmdline(':', {
         sources = cmp.config.sources({
           { name = 'path' }
         }, {
           { name = 'cmdline' }
         }),
            --formatting = {
            -- format = function(_, vim_item)
            --   vim_item.kind = cmdIcons[vim_item.kind] or "FOO"
            -- return vim_item
            --end
       -- }
       })
       require("copilot").setup({
         suggestion = { enabled = false },
         panel = { enabled = false },
       })
       local _border = "rounded"

       vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
         vim.lsp.handlers.hover, {
           border = _border
         }
       )

       vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
         vim.lsp.handlers.signature_help, {
           border = _border
         }
       )

       vim.diagnostic.config{
         float={border=_border}
       };

       require('lspconfig.ui.windows').default_options = {
         border = _border
       }
    '';

    plugins = {
      conform-nvim = {
        enable = true;
        formatOnSave = {
          lspFallback = true;
          timeoutMs = 500;
        };
        notifyOnError = true;
        formattersByFt = {
          go = [ "gofmt" ];
          python = [ "black" ];
          lua = [ "stylua" ];
          nix = [ "alejandra" ];
          markdown = [[ "prettierd" "prettier" ]];
          #yaml = ["yamllint" "yamlfmt"];
        };
      };
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
      cmp = {
        enable = true;
        settings = {
          autoEnableSources = true;
          experimental = { ghost_text = true; };
          performance = {
            debounce = 60;
            fetchingTimeout = 200;
            maxViewEntries = 30;
          };
          snippet = { expand = "luasnip"; };
          formatting = { fields = [ "kind" "abbr" "menu" ]; };
          sources = [
            { name = "nvim_lsp"; }
            { name = "emoji"; }
            {
              name = "buffer"; # text within current buffer
              option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
              keywordLength = 3;
            }
            { name = "copilot"; }
            {
              name = "path"; # file system paths
              keywordLength = 3;
            }
            {
              name = "luasnip"; # snippets
              keywordLength = 3;
            }
          ];

          window = {
            completion = { border = "solid"; };
            documentation = { border = "solid"; };
          };

          mapping = {
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            "<C-j>" = "cmp.mapping.select_next_item()";
            "<C-k>" = "cmp.mapping.select_prev_item()";
            "<C-e>" = "cmp.mapping.abort()";
            "<C-b>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-Space>" = "cmp.mapping.complete()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<S-CR>" =
              "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
          };
        };
      };
      cmp-buffer = { enable = true; };
      cmp-path = { enable = true; };
      cmp-nvim-lsp = { enable = true; };
      cmp_luasnip = { enable = true; };
      cmp-cmdline = { enable = true; };
      copilot-cmp = { enable = true; };
      copilot-lua = {
        enable = true;
        suggestion = { enabled = false; };
        panel = { enabled = false; };
      };

      flash = { enable = true; };
      gitsigns = {
        enable = true;
        settings = { trouble = true; };
      };
      illuminate = {
        enable = true;
        delay = 200;
        largeFileCutoff = 2000;
        largeFileOverrides = { providers = [ "lsp" ]; };
      };
      lint = { enable = true; };
      luasnip = {
        enable = true;
        extraConfig = {
          enable_autosnippets = true;
          store_selection_keys = "<Tab>";
        };
        fromVscode = [{
          lazyLoad = true;
          paths = "${pkgs.vimPlugins.friendly-snippets}";
        }];
      };
      friendly-snippets = { enable = true; };
      nvim-autopairs = { enable = true; };
      telescope = {
        enable = true;
        extensions = {
          file-browser = { enable = true; };
          fzf-native = { enable = true; };
        };
        settings = {
          defaults = {
            layout_config = { horizontal = { prompt_position = "top"; }; };
            sorting_strategy = "ascending";
          };
        };
        keymaps = {
          "<leader>/" = {
            action = "live_grep";
            options = { desc = "Grep (root dir)"; };
          };
          "<leader>:" = {
            action = "command_history, {}";
            options = { desc = "Command History"; };
          };
          "<leader>b" = {
            action = "buffers, {}";
            options = { desc = "+buffer"; };
          };
          "<leader>ff" = {
            action = "find_files, {}";
            options = { desc = "Find project files"; };
          };
          "<leader>fr" = {
            action = "live_grep, {}";
            options = { desc = "Find text"; };
          };
          "<leader>fR" = {
            action = "resume, {}";
            options = { desc = "Resume"; };
          };
          "<leader>fg" = {
            action = "oldfiles, {}";
            options = { desc = "Recent"; };
          };
          "<leader>fb" = {
            action = "buffers, {}";
            options = { desc = "Buffers"; };
          };
          "<C-p>" = {
            action = "git_files, {}";
            options = { desc = "Search git files"; };
          };
          "<leader>gc" = {
            action = "git_commits, {}";
            options = { desc = "Commits"; };
          };
          "<leader>gs" = {
            action = "git_status, {}";
            options = { desc = "Status"; };
          };
          "<leader>sa" = {
            action = "autocommands, {}";
            options = { desc = "Auto Commands"; };
          };
          "<leader>sb" = {
            action = "current_buffer_fuzzy_find, {}";
            options = { desc = "Buffer"; };
          };
          "<leader>sc" = {
            action = "command_history, {}";
            options = { desc = "Command History"; };
          };
          "<leader>sC" = {
            action = "commands, {}";
            options = { desc = "Commands"; };
          };
          "<leader>sD" = {
            action = "diagnostics, {}";
            options = { desc = "Workspace diagnostics"; };
          };
          "<leader>sh" = {
            action = "help_tags, {}";
            options = { desc = "Help pages"; };
          };
          "<leader>sH" = {
            action = "highlights, {}";
            options = { desc = "Search Highlight Groups"; };
          };
          "<leader>sk" = {
            action = "keymaps, {}";
            options = { desc = "Keymaps"; };
          };
          "<leader>sM" = {
            action = "man_pages, {}";
            options = { desc = "Man pages"; };
          };
          "<leader>sm" = {
            action = "marks, {}";
            options = { desc = "Jump to Mark"; };
          };
          "<leader>so" = {
            action = "vim_options, {}";
            options = { desc = "Options"; };
          };
          "<leader>sR" = {
            action = "resume, {}";
            options = { desc = "Resume"; };
          };
          "<leader>uC" = {
            action = "colorscheme, {}";
            options = { desc = "Colorscheme preview"; };
          };
        };
      };
      ts-context-commentstring = { enable = true; };
      ts-autotag = { enable = true; };
      treesitter = { enable = true; };
      treesitter-textobjects = { enable = true; };
      treesitter-context = { enable = true; };
      trouble = {
        enable = true;
        settings = {
          auto_close = true;
          use_lsp_diagnostic_signs = true;
        };
      };
      todo-comments = { enable = true; };
      which-key = { enable = true; };

      neo-tree = {
        enable = true;
        filesystem = {
          bindToCwd = false;
          followCurrentFile = { enabled = true; };
        };
      };
      noice = {
        enable = true;
        presets = { bottom_search = true; };
      };
      lsp-format = { enable = true; };
      lspkind = {
        enable = true;
        symbolMap = { Copilot = ""; };
        extraOptions = {
          maxwidth = 50;
          ellipsis_char = "...";
        };
      };

      lsp = {
        enable = true;
        servers = {
          ansiblels = { enable = true; };
          bashls = { enable = true; };
          gopls = { enable = true; };
          lua-ls = { enable = true; };
          pyright = { enable = true; };
          nil_ls = { enable = true; };
          terraformls = { enable = true; };
          yamlls = { enable = false; };
        };
        capabilities = ''
          workspace = { didChangeWatchedFiles = { dynamicRegistration = true }}
        '';
        keymaps = {
          silent = true;
          lspBuf = {
            gd = {
              action = "definition";
              desc = "Goto Definition";
            };
            gr = {
              action = "references";
              desc = "Goto References";
            };
            gD = {
              action = "declaration";
              desc = "Goto Declaration";
            };
            gI = {
              action = "implementation";
              desc = "Goto Implementation";
            };
            gT = {
              action = "type_definition";
              desc = "Type Definition";
            };
            K = {
              action = "hover";
              desc = "Hover";
            };
            "<leader>cw" = {
              action = "workspace_symbol";
              desc = "Workspace Symbol";
            };
            "<leader>cr" = {
              action = "rename";
              desc = "Rename";
            };
          };
          diagnostic = {
            "<leader>cd" = {
              action = "open_float";
              desc = "Line Diagnostics";
            };
            "[d" = {
              action = "goto_next";
              desc = "Next Diagnostic";
            };
            "]d" = {
              action = "goto_prev";
              desc = "Previous Diagnostic";
            };
          };
        };
      };
      notify = { enable = true; };
      dressing = { enable = true; };

      bufferline = { enable = true; };
      lualine = { enable = true; };
      indent-blankline = { enable = true; };
      persistence = { enable = true; };
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

