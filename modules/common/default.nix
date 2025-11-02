{
  pkgs,
  inputs,
  username,
  ...
}:
{
  # Shared Nix configuration across all platforms
  nix.settings = {
    experimental-features = "nix-command flakes";
    trusted-users = [
      username
      "@wheel"
      "@admin"
    ];
    trusted-substituters = [
      "https://cache.flox.dev"
    ];
    trusted-public-keys = [
      "cullen:gtI9d0t7nPTU36OnGU6YpEP5wEndvbmna9+7jpCgWPg= "
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
    # Performance optimizations for faster downloads/builds
    download-buffer-size = 268435456;  # 256 MB (default is 64 MB)
    max-substitution-jobs = 16;        # More parallel downloads
    max-jobs = "auto";                 # Use all CPU cores for builds
  };

  # Shared system packages across all platforms
  environment.systemPackages = [
    inputs.flox.packages.${pkgs.stdenv.hostPlatform.system}.default  # Using flox's recommended approach
    inputs.dagger.packages.${pkgs.stdenv.hostPlatform.system}.dagger
  ];
}
