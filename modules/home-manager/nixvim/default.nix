{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./conform.nix
    ./neotree.nix
    ./telescope.nix
    ./lsp.nix
    ./cmp.nix
  ];
  globals = {mapleader = " ";};
  colorschemes = {
    tokyonight = {
      enable = true;
      settings = {
        style = "storm";
        light_style = "day";
        transparent = false;
        terminal_colors = true;
        styles = {
          comments.italic = true;
          keywords.italic = true;
          functions = {};
          variables = {};
          sidebars = "dark";
          floats = "dark";
        };
      };
    };
  };
  plugins = {
    toggleterm = {
      enable = true;
      settings = {
        open_mapping = "[[<C-/>]]";
        direction = "float";
      };
    };
    which-key = {enable = true;};
    gitsigns = {
      enable = true;
      settings = {trouble = true;};
    };
    trouble = {
      enable = true;
      settings = {
        auto_close = true;
        lsp_diagnostic_signs = true;
      };
    };
    noice = {
      enable = true;
      presets = {bottom_search = true;};
    };
    notify = {enable = true;};
    dressing = {enable = true;};

    bufferline = {enable = true;};
    lualine = {enable = true;};
    indent-blankline = {enable = true;};
    persistence = {enable = true;};
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
    todo-comments = {enable = true;};
  };
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
      action = "<cmd>Neotree toggle<cr>";
      options = {
        silent = false;
        desc = "Toggle neotree";
      };
    }
    {
      mode = "n";
      key = "<leader>gmt";
      action = "<cmd>GoModTidy<cr>";
      options = {
        silent = false;
        desc = "Go Mod Tidy and Restart LSP";
      };
    }
    {
      # Escape terminal mode using ESC
      mode = "t";
      key = "<esc>";
      action = "<C-\\><C-n>";
      options.desc = "Escape terminal mode";
    }
  ];
  opts = {
    number = true;
    colorcolumn = "80";
    relativenumber = false;
    tabstop = 2;
    softtabstop = 2;
    showtabline = 2;
    expandtab = true;

    # Enable auto indenting and set it to spaces
    smartindent = true;
    shiftwidth = 2;

    # Enable smart indenting (see https://stackoverflow.com/questions/1204149/smart-wrap-in-vim)
    breakindent = true;

    # Enable incremental searching
    hlsearch = true;
    incsearch = true;

    # Enable text wrap
    wrap = true;

    # Better splitting
    splitbelow = true;
    splitright = true;

    # Enable mouse mode
    mouse = "a"; # Mouse

    # Enable ignorecase + smartcase for better searching
    ignorecase = true;
    smartcase = true; # Don't ignore case with capitals
    grepprg = "rg --vimgrep";
    grepformat = "%f:%l:%c:%m";

    # Decrease updatetime
    updatetime = 50; # faster completion (4000ms default)

    # Set completeopt to have a better completion experience
    completeopt = ["menuone" "noselect" "noinsert"]; # mostly just for cmp

    # Enable persistent undo history
    swapfile = false;
    backup = false;
    undofile = true;

    # Enable 24-bit colors
    termguicolors = true;

    # Enable the sign column to prevent the screen from jumping
    # signcolumn = "yes";

    # Enable cursor line highlight
    cursorline = true; # Highlight the line where the cursor is located

    # Set fold settings
    # These options were reccommended by nvim-ufo
    # See: https://github.com/kevinhwang91/nvim-ufo#minimal-configuration
    foldcolumn = "0";
    foldlevel = 99;
    foldlevelstart = 99;
    foldenable = true;

    # Always keep 8 lines above/below cursor unless at start/end of file
    scrolloff = 8;

    # Place a column line
    # colorcolumn = "80";

    # Reduce which-key timeout to 10ms
    timeoutlen = 10;

    # Set encoding type
    encoding = "utf-8";
    fileencoding = "utf-8";

    # More space in the neovim command line for displaying messages
    cmdheight = 0;

    # We don't need to see things like INSERT anymore
    showmode = false;
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
     require("go").setup()
     require("CopilotChat").setup {
       debug = true, -- Enable debugging
       -- See Configuration section for rest
     }
  '';
  extraPlugins = [
    (
      pkgs.vimUtils.buildVimPlugin {
        name = "go.nvim";
        src = pkgs.fetchFromGitHub {
          owner = "ray-x";
          repo = "go.nvim";
          rev = "1423d5d0820eeefc97d6cdaf3ae8b554676619cc";
          hash = "sha256-GqkkZ0WZBw+FXeTM1+Grqe+VOZIC9PVRFo6lFmQAZu8=";
        };
      }
    )
    (
      pkgs.vimUtils.buildVimPlugin {
        name = "CopilotChat.nvim";
        src = pkgs.fetchFromGitHub {
          owner = "CopilotC-Nvim";
          repo = "CopilotChat.nvim";
          rev = "feca60cf0ae08d866ba35cc8a95d12941ccc4f59";
          hash = "sha256-dE5Q3WeLn9gY4KBIyhhDjkfxWeBuvlKmsdaSMkwEcUM=";
        };
      }
    )
  ];
}
