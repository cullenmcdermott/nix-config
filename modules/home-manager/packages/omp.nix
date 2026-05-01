{ pkgs, lib }:

# oh-my-pi (omp) — a fork of pi-coding-agent with LSP integration, TTSR rules,
# hashline edits, native Rust engine, commit tool, web search/fetch, and many more
# enhancements over upstream pi.
#
# Uses the prebuilt binary from GitHub releases for reproducibility.
# To update: change `version` below, then run:
#   nix-prefetch-url https://github.com/can1357/oh-my-pi/releases/download/v<VERSION>/omp-darwin-arm64
#   nix hash convert --hash-algo sha256 --to sri <hash-from-above>
#
# Then update the hash for your platform in the hashes attrset.
let
  version = "14.5.14";
  hashes = {
    # aarch64-darwin — update with: nix hash convert --hash-algo sha256 --to sri $(nix-prefetch-url https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64 | tail -1)
    "aarch64-darwin" = "sha256-qEhhJ8Vn1B5GU4DhHp344P3ShJTB9hhH0Ooa0i0x4e4=";
    # x86_64-darwin — not yet fetched
    "x86_64-darwin" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # x86_64-linux — not yet fetched
    "x86_64-linux" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    # aarch64-linux — not yet fetched
    "aarch64-linux" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  src = pkgs.fetchurl {
    url =
      {
        "aarch64-darwin" = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64";
        "x86_64-darwin" = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-x64";
        "x86_64-linux" = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
        "aarch64-linux" = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
      }
      .${pkgs.stdenv.hostPlatform.system} or (throw "Unsupported platform: ${pkgs.stdenv.hostPlatform.system}");
    hash =
      hashes.${pkgs.stdenv.hostPlatform.system}
        or (throw "No hash for platform: ${pkgs.stdenv.hostPlatform.system}");
  };
in
pkgs.stdenv.mkDerivation {
  pname = "omp";
  inherit version;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp ${src} $out/bin/omp
    chmod +x $out/bin/omp
    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent for the terminal (enhanced fork of pi-coding-agent)";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "omp";
  };
}