{
  pkgs,
  ...
}:
let
  shellAliases = {
    v = "nvim";
    vdiff = "nvim -d";
  };
in
{
  # recursive = true symlinks each file individually so nvim can still write
  # into its own config tree at runtime.
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };

  home.shellAliases = shellAliases;

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
