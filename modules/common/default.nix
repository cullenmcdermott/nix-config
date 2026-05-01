{
  username,
  ...
}:
{
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
      "floxhub-1:0QOAlcobcEvq1mqEf4qAYCaWnTTOXpyoRv/PmqfSixM="
    ];
    download-buffer-size = 268435456;
    max-substitution-jobs = 16;
    max-jobs = "auto";
  };
}
