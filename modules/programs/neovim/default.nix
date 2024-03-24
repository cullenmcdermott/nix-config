{ pkgs, ... }:
let

  treesitterWithGrammars = (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
    p.bash
    p.comment
    p.dockerfile
    p.gitattributes
    p.gitignore
    p.go
    p.gomod
    p.gowork
    p.hcl
    p.javascript
    p.jq
    p.json5
    p.json
    p.lua
    p.make
    p.markdown
    p.nix
    p.python
    p.toml
    p.typescript
    p.vue
    p.yaml
  ]));
in
{
  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    terraform-ls
    nixd
    lua-language-server
    black
  ];

  programs.neovim = {
    enable = true;
    vimAlias = true;
    coc.enable = false;
    withNodeJs = true;

    plugins = [
      treesitterWithGrammars
    ];
  };

  home.file."./.config/nvim/" = {
    source = ./nvim;
    recursive = true;
  };

  # Treesitter is configured as a locally developed module in lazy.nvim
  # we hardcode a symlink here so that we can refer to it in our lazy config
  home.file."./.local/share/nvim/nix/nvim-treesitter/" = {
    recursive = true;
    source = treesitterWithGrammars;
  };

}
