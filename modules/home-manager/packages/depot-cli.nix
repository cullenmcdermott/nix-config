{ pkgs, lib, ... }:

let
  version = "2.101.36";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/depot/cli/releases/download/v${version}/depot_${version}_darwin_arm64.tar.gz";
      hash = "sha256-DKf5mlvyTojReSvLfWOfX1rlV/7rznKVyGFRo9dDuQM=";
    };
    "x86_64-linux" = {
      url = "https://github.com/depot/cli/releases/download/v${version}/depot_${version}_linux_amd64.tar.gz";
      hash = "sha256-0BeH1TjsdbuK75dL3GHHr66tfs4XgFTIUs0eeX5SIS8=";
    };
  };

  src = pkgs.fetchurl {
    inherit (sources.${pkgs.stdenv.hostPlatform.system}) url hash;
  };
in
pkgs.stdenv.mkDerivation {
  pname = "depot-cli";
  inherit version src;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals pkgs.stdenv.isDarwin [
    pkgs.fixDarwinDylibNames
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp bin/depot $out/bin/depot
    chmod +x $out/bin/depot
  '';

  meta = with lib; {
    description = "CLI for Depot - fast container builds";
    homepage = "https://depot.dev";
    license = licenses.mit;
    platforms = builtins.attrNames sources;
  };
}
