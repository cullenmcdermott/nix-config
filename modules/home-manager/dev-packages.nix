{
  pkgs,
  lib,
  ...
}:
let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      gke-gcloud-auth-plugin
    ]
  );
in
{
  home.packages =
    with pkgs;
    [
      alejandra
      argc
      argocd
      cargo
      chart-testing
      google-chrome
      copilot-language-server
      curl
      deadnix
      docker
      docker-compose
      fd
      flyctl
      gdk
      gh
      git
      gopls
      go
      jq
      just
      k9s
      kubie
      kubecolor
      kubectl
      kubelogin-oidc
      kubernetes-helm
      krew
      less
      luajitPackages.lua-lsp
      nixd
      nixfmt
      nodejs
      omnictl
      packer
      python3
      pipx
      pyright
      qemu
      (renovate.overrideAttrs (oldAttrs: {
        nativeBuildInputs =
          (oldAttrs.nativeBuildInputs or [ ])
          ++ lib.optionals stdenv.isDarwin [
            darwin.cctools
          ];
      }))
      ast-grep
      delta
      difftastic
      hyperfine
      ripgrep
      sd
      scc
      shellcheck
      silver-searcher
      skopeo
      watchexec
      yq-go
      statix
      talosctl
      tailscale
      terraform
      terraform-ls
      tflint
      typescript-language-server
      unzip
      uv
      unixtools.watch
      vscode
      wget
      playwright-mcp
      playwright-driver
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      _1password-cli
      aerospace
      colima
      lima
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      kdePackages.ksshaskpass
      obs-studio
      vlc
      k3d
    ];
}
