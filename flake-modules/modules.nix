# Public module exports. Downstream flakes (e.g. the work laptop config)
# import these directly via inputs.system-config.darwinModules.* and
# inputs.system-config.homeManagerModules.*.
{ ... }:
{
  flake.darwinModules = {
    default = ../modules/darwin;
    shared = ../modules/common;
  };

  flake.homeManagerModules = {
    default = ../modules/home-manager;
  };
}
