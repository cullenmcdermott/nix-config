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
in
{
  home.activation.installAstroNvim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.rsync}/bin/rsync -avz --delete --chmod=D2755,F744 ${./nvim}/ ${config.xdg.configHome}/nvim/
  '';

  home.shellAliases = shellAliases;
  programs.nushell.shellAliases = shellAliases;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
    ];
  };
}
