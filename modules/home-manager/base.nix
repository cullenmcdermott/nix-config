{
  pkgs,
  lib,
  username,
  ...
}:
{
  home.stateVersion = lib.mkDefault "24.05";

  # Single source of truth for the home directory, derived from username +
  # platform. mkForce is required because the nix-darwin home-manager
  # integration injects a normal-priority `home.homeDirectory = null` that a
  # plain default would lose to.
  home.homeDirectory = lib.mkForce (
    if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"
  );
}
