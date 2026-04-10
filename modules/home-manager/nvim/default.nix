{
  config,
  lib,
  pkgs,
  ...
}:
###############################################################################
#
#  AstroNvim's configuration and all its dependencies(lsp, formatter, etc.)
#
#e#############################################################################
let
  shellAliases = {
    v = "nvim";
    vdiff = "nvim -d";
  };

  # Recursively collect all files under a directory and produce
  # xdg.configFile entries mapping them into nvim/.
  nvimSource = ./nvim;
  collectFiles = prefix: dirPath:
    lib.concatMapAttrs (name: type:
      let
        relPath = "${prefix}${name}";
        absPath = dirPath + "/${name}";
      in
      if type == "directory" then
        collectFiles "${relPath}/" absPath
      else
        { "nvim/${relPath}" = { source = absPath; }; }
    ) (builtins.readDir dirPath);
in
{
  xdg.configFile = collectFiles "" nvimSource;

  home.shellAliases = shellAliases;
  programs.nushell.shellAliases = shellAliases;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
    ];
  };
}
