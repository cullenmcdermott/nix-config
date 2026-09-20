{
  pkgs,
  lib,
  username,
  ...
}:
{
  home.stateVersion = lib.mkDefault "24.05";

  # Standalone default; integrated hosts supply users.users.<name>.home.
  home.homeDirectory = lib.mkDefault (
    if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"
  );
}
