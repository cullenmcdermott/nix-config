# Claude Code Package - Native binary from Anthropic's GCS bucket
# Based on https://github.com/sadjow/claude-code-nix
#
# Usage:
#   callPackage ./claude-code.nix { }                    # use default version
#   callPackage ./claude-code.nix { version = "2.1.40"; platformHashes = { ... }; }  # override

{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, procps
, ripgrep
, bubblewrap
, socat
, version ? "2.1.36"
, platformHashes ? {
    "darwin-arm64" = "1r0mc6nih325lga5b0bh283xaflv0pg0i9ddj84ns97cagvqmnhk";
    "darwin-x64" = "0v5d2py89g685mm239hhbwgpl63l7z6r1gwcbvviffdgmhmqw53r";
    "linux-x64" = "198a834c4jblffh12h2fbhlwnichvn8642fyc7bn0ap6dgwfcril";
    "linux-arm64" = "18rsc1p35v24wsp6x4yvwhw9cfssy5c8x9lxc7rxw3iz635nh7n0";
  }
}:

let
  platformMap = {
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
  };

  platform = platformMap.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  binaryUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platform}/claude";

  binary = fetchurl {
    url = binaryUrl;
    sha256 = platformHashes.${platform};
  };
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  dontUnpack = true;
  dontStrip = true; # Stripping corrupts the Bun binary trailer

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isElf [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    install -m755 ${binary} $out/bin/.claude-unwrapped

    makeBinaryWrapper $out/bin/.claude-unwrapped $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix PATH : ${
        lib.makeBinPath (
          [ procps ripgrep ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap socat ]
        )
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code - AI coding assistant in your terminal";
    homepage = "https://www.anthropic.com/claude-code";
    license = licenses.unfree;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = "claude";
  };
}
