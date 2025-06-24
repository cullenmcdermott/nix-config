{
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.overlays = [
    # Zen Browser overlay
    (final: prev: {
      zen-browser = prev.stdenv.mkDerivation rec {
        pname = "zen-browser";
        version = "1.13.2b";

        src = prev.fetchurl {
          url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-x86_64.tar.xz";
          sha256 = "sha256-GOD/qZsdCIgldRsOR/Hxo+mBOK7iutKt9XYUj9+6Tgc=";
        };

        nativeBuildInputs = with prev; [
          autoPatchelfHook
          wrapGAppsHook
        ];

        buildInputs = with prev; [
          gtk3
          cairo
          gdk-pixbuf
          glib
          pango
          atk
          at-spi2-atk
          dbus
          fontconfig
          freetype
          libxkbcommon
          xorg.libX11
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXrandr
          xorg.libxcb
          expat
          libdrm
          libGL
          mesa
        ];

        installPhase = ''
          mkdir -p $out/bin $out/lib/zen-browser
          cp -r * $out/lib/zen-browser/
          ln -s $out/lib/zen-browser/zen $out/bin/zen-browser
        '';

        meta = with lib; {
          description = "Experience tranquillity while browsing the web without people tracking you!";
          homepage = "https://zen-browser.app/";
          license = licenses.mpl20;
          platforms = platforms.linux;
        };
      };
    })
  ];
}
