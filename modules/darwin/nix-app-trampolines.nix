{
  config,
  pkgs,
  ...
}:
{
  system.activationScripts.extraActivation.text = ''
    apps_source="${config.system.build.applications}/Applications"
    echo "apps source is $apps_source"
    moniker="Nix Trampolines"
    app_target_base="$HOME/Applications"
    app_target="$app_target_base/$moniker"
    mkdir -p "$app_target"
    ${pkgs.rsync}/bin/rsync --verbose --archive --checksum --chmod=-w --copy-unsafe-links --delete "$apps_source/" "$app_target"
  '';
}
