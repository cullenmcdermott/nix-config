{ pkgs, lib, ... }:

{
  imports = [ ./neotree.nix ];
  globals = { mapleader = " "; };
  colorschemes = { tokyonight = { enable = true; }; };
  plugins = {
          which-key = { enable = true; };

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
    completeopt = [ "menuone" "noselect" "noinsert" ]; # mostly just for cmp

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
}
