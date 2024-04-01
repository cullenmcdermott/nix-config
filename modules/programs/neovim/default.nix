{ pkgs, ... }:

{
  
  programs.nixvim = {
    enable = true;
    globals.mapleader = "^";
    colorschemes.gruvbox.enable = true;

    plugins = {};
  };


}

