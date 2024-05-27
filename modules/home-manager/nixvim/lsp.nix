{
  plugins.lsp-format = {
    enable = true;
  };
  plugins.lspkind = {
    enable = true;
    symbolMap = {Copilot = "";};
    extraOptions = {
      maxwidth = 50;
      ellipsis_char = "...";
    };
  };
  plugins.lsp = {
    enable = true;
    servers = {
      ansiblels = {enable = true;};
      bashls = {enable = true;};
      gopls = {enable = true;};
      lua-ls = {enable = true;};
      pyright = {enable = true;};
      nil_ls = {enable = true;};
      terraformls = {enable = true;};
      yamlls = {enable = false;};
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
}
