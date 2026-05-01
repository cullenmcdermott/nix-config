{ ... }: {
  imports = [
    ./mac-defaults.nix
    ./nix-gc.nix
    ./nix-app-trampolines.nix
    ./homebrew-base.nix
    ./homebrew-personal.nix
  ];
}
