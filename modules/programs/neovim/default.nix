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
    lua-language-server
    black
  ];

  programs.neovim = {
    enable = true;
    globals.mapleader = "^";
    colorschemes.gruvbox.enable = true;

    plugins = {};
  };
}

