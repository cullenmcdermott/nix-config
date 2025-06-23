{ pkgs, inputs, ... }:
{
  # Shared Nix configuration across all platforms
  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-substituters = [
      "https://cache.flox.dev"
    ];
    trusted-public-keys = [
      "cullen:gtI9d0t7nPTU36OnGU6YpEP5wEndvbmna9+7jpCgWPg= "
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };

  # Shared system packages across all platforms
  environment.systemPackages = [
    inputs.flox.packages.${pkgs.system}.default
    inputs.dagger.packages.${pkgs.system}.dagger
  ];
}