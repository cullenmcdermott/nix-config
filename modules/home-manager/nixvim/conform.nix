{
  plugins.conform-nvim = {
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
}
