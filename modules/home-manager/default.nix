{
  config,
  pkgs,
  lib,
  username,
  inputs,
  ...
}:
let
  gdk = pkgs.google-cloud-sdk.withExtraComponents (
    with pkgs.google-cloud-sdk.components;
    [
      gke-gcloud-auth-plugin
    ]
  );

  # Platform detection - enables cross-platform compatibility
  homeDirectory =
    if pkgs.stdenv.isDarwin then
      "/Users/${username}" # macOS - same as before
    else
      "/home/${username}"; # Linux - for future NixOS support

  # Fetch the entire Claude Code skills repository
  claudeSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "f232228244495c018b3c1857436cf491ebb79bbb";
    hash = "sha256-/u7NC9opHNXh9kQMWYzeLyurdQPPHULiCTUbvTZsXeU=";
  };

  # Flox agentic skills from flake input
  floxAgentic = inputs.flox-agentic;


in
{
  # specify home-manager configs
  imports = [
    ./nvim
    ./packages
    ./claude-code.nix
    ./zwift-media.nix
  ];
  home.stateVersion = "24.05";
  home.packages =
    with pkgs; # All packages are unstable now
    [
      # Core packages available on all platforms
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
      nixfmt-rfc-style
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
      # MCP Servers - installed via Nix for reproducibility
      playwright-mcp # From nixpkgs
      playwright-driver # Playwright browser driver
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # macOS-specific packages
      _1password-cli
      aerospace
      colima
      lima
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Essential Linux packages for distrobox environment
      kdePackages.ksshaskpass
      obs-studio
      vlc
      k3d
    ];
  xdg = {
    enable = true;
    cacheHome = "${homeDirectory}/.cache";
    configHome = "${homeDirectory}/.config";
    configFile."ghostty/config" = {
      text = ''
        theme = TokyoNight Storm
        font-family = JetBrainsMono Nerd Font
        font-style = medium
        font-size = 14
        macos-titlebar-style = tabs
        background-opacity = 0.90
        background-blur-radius = 10
        window-padding-x = 10
        window-padding-y = 10
        keybind = super+shift+h=previous_tab
        keybind = super+shift+l=next_tab
        keybind = super+shift+r=reload_config
        keybind = shift+enter=text:\x1b\r
        scrollback-limit = 2147483648
      '';
    };
  };
  home.homeDirectory = lib.mkForce homeDirectory;
  home.sessionVariables = {
    PAGER = "less";
    EDITOR = "nvim";
    HOME = homeDirectory;
    TERM = "xterm";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/node_modules/.bin"
  ];
  programs.bat.enable = true;
  programs.bat.config.theme = "TwoDark";
  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;
  programs.zsh.enable = true;
  programs.zsh.dotDir = "${config.xdg.configHome}/zsh";
  programs.zsh.enableCompletion = true;
  programs.zsh.autosuggestion.enable = true;
  programs.zsh.history = {
    size = 10000000;
    save = 10000000;
    path = "${config.xdg.dataHome}/zsh/history";
    extended = true;
    share = true;
    append = true;
  };
  programs.zsh.syntaxHighlighting.enable = true;
  programs.zsh.initContent = ''
    ${builtins.readFile ./dotfiles/zshrc}
  '';
  programs.zsh.shellAliases = {
    brew = "op plugin run -- brew";
    ls = "ls --color=auto -F";
    vim = "nvim";
    nixswitch = "sudo darwin-rebuild switch --flake ~/src/system-config/.#";
    nixup = "pushd ~/src/system-config && nix flake update && sudo darwin-rebuild switch --flake ~/src/system-config/.#; popd";
    k = "kubecolor";
    ga = "git add";
    gb = "git branch";
    gbD = "git branch -D";
    gc = "git commit -v";
    gcma = "git checkout main";
    gco = "git checkout";
    gcb = "git checkout -b";
    gd = "git diff";
    gl = "git pull";
    glola = "git log --graph --pretty='''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset''' --all";
    gm = "git merge";
    gp = "git push";
    grb = "git rebase";
    gst = "git status";
    gcl = "git clone";
    grv = "git remote -v";
    # NOTE: claude and clod aliases are now managed by programs.claude-code module
  };

  programs.zsh.plugins = [ ];
  programs.zsh.oh-my-zsh.enable = false;
  programs.direnv.enable = true;
  programs.starship.enable = true;
  programs.starship.enableZshIntegration = true;

  # Zwift Ride media controls - set to false to disable
  programs.zwift-media.enable = pkgs.stdenv.isDarwin;

  # --- Claude Code Configuration (upstream home-manager module) ---
  programs.claude-code = {
    enable = true;

    # Settings (flat JSON merged into ~/.claude/settings.json)
    settings = {
      permissions = {
        allow = [
          "Read"
          "Glob"
          "Grep"
          "LS"
          "WebFetch"
          "WebSearch"
          # Read-only bash commands
          "Bash(ls:*)"
          "Bash(find:*)"
          "Bash(grep:*)"
          "Bash(rg:*)"
          "Bash(cat:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(git status)"
          "Bash(git log:*)"
          "Bash(git diff:*)"
          "Bash(git show:*)"
          "Bash(mkdir:*)"
          "Bash(chmod:*)"
          # Additional useful bash commands
          "Bash(nix search:*)"
          "Bash(nix-env:*)"
          "Bash(time zsh:*)"
          "Bash(zsh:*)"
          # Modern CLI tools (read-only / analysis)
          "Bash(sg:*)"
          "Bash(ast-grep:*)"
          "Bash(difft:*)"
          "Bash(shellcheck:*)"
          "Bash(scc:*)"
          "Bash(yq:*)"
          "Bash(delta:*)"
          "Bash(hyperfine:*)"
          # LLM orchestration CLIs
          "Bash(cursor-agent:*)"
          "Bash(uv run:*)"
        ];
      };
      interactiveMode = true;
      autoCompact = false;
      sandbox = {
        enabled = true;
        autoAllowBashIfSandboxed = true;
      };
    };

    # CLAUDE.md content
    memory.text = ''
      ## Environment
      This is a Nix-managed system (nix-darwin + home-manager). All packages are declaratively managed.
      - **Never install packages imperatively** — do not use `brew install`, `npm install -g`, `pip install`, `cargo install`, `go install`, or `apt-get`. If a tool is needed permanently, tell the user to add it to their Nix config.
      - **For one-off commands**, use `nix run nixpkgs#<package>` (e.g., `nix run nixpkgs#cowsay -- hello`).
      - **For temporary shell sessions** with a package, use `nix shell nixpkgs#<package>`.
      - **To search for packages**, use `nix search nixpkgs <query>`.
      - Do not assume a tool is available unless it is listed below or you have verified it exists on the system.
      - **LSP servers are Nix-managed.** Do not install LSP plugins from the Claude Code marketplace. All language server configuration is declarative via the `programs.claude-code-nix.lsp.servers` option.

      ## Sandbox Awareness
      - If a command fails with unexpected "permission denied", TLS errors, or connection refused, it is likely a sandbox restriction. Retry the command outside the sandbox before investigating other causes.

      ## Verify Before Claiming
      - Always verify state with actual commands before making claims. Do not assert that code isn't pushed, tags don't exist, or services aren't running without checking first.
      - When debugging, form hypotheses and test them with commands — do not state assumptions as fact.

      ## Destructive Changes
      - Before removing, deleting, or cleaning up resources, confirm the replacement is fully working first. Never prematurely remove old infrastructure during migrations.
      - For multi-step migrations: deploy new -> migrate data -> verify -> clean up old, with confirmation at each gate.

      ## Safety
      - When using `op` or another CLI command that will output sensitive information, never directly read the secrets — redact before printing to stdout.

      ## Preferences
      - Prefer Mermaid diagrams over ASCII diagrams.
      - When performing complex logic, write a script (preferably in python or go) and run it rather than trying to run/wrap all commands in a single bash -c or equivalent call

      ## Available CLI Tools
      Prefer these over traditional alternatives (e.g., use `sd` not `sed`, `difft` not `diff`, `rg` not `grep`, `fd` not `find`, `bat` not `cat`):
      - `sg` (ast-grep): Structural code search/refactor using AST patterns. Prefer over regex for code-aware searches.
      - `difft` (difftastic): Syntax-aware structural diff.
      - `shellcheck`: Shell script linter. Run on shell scripts before executing them.
      - `sd`: Modern `sed` replacement with standard regex syntax.
      - `scc`: Fast code counter for project overviews.
      - `yq`: Query and modify YAML, JSON, TOML, and XML while preserving comments.
      - `hyperfine`: Statistical command benchmarking.
      - `watchexec`: Run commands on file changes.
      - `delta`: Syntax-highlighting pager for git diffs.
      - `rg` (ripgrep), `fd`, `bat`, `jq`, `curl`, `gh` (GitHub CLI)
    '';

    # Skills (upstream: path = directory, string = inline SKILL.md content)
    skills = {
      # From official Anthropic skills repo
      slack-gif-creator = "${claudeSkills}/slack-gif-creator";
      skill-creator = "${claudeSkills}/skill-creator";
      frontend-design = "${claudeSkills}/skills/frontend-design";

      # Local custom skills
      home-assistant = ./../../skills/home-assistant;
      llm-orchestrator = ./../../skills/llm-orchestrator;
      claude-code-config = ./../../skills/claude-code-config;

      # Flox agentic skills
      flox-environments = "${floxAgentic}/flox-plugin/skills/flox-environments";
      flox-services = "${floxAgentic}/flox-plugin/skills/flox-services";
      flox-builds = "${floxAgentic}/flox-plugin/skills/flox-builds";
      flox-containers = "${floxAgentic}/flox-plugin/skills/flox-containers";
      flox-publish = "${floxAgentic}/flox-plugin/skills/flox-publish";
      flox-sharing = "${floxAgentic}/flox-plugin/skills/flox-sharing";
      flox-cuda = "${floxAgentic}/flox-plugin/skills/flox-cuda";
    };

    # Agents and commands from repo root directories
    agentsDir = ./../../agents;
    commandsDir = ./../../commands;
  };

  # --- Claude Code Nix Extensions (our custom module) ---
  programs.claude-code-nix = {
    enable = true;

    # MCP servers (written to ~/.claude/mcp.json, auto-read by Claude Code)
    mcpServers.playwright = {
      command = "mcp-server-playwright-wrapper";
      args = [ ];
      env = { };
    };

    # LSP servers with absolute Nix store paths
    lsp.servers = {
      go = {
        command = "${pkgs.gopls}/bin/gopls";
        args = [ "serve" ];
        extensionToLanguage = { ".go" = "go"; };
      };
      python = {
        command = "${pkgs.pyright}/bin/pyright-langserver";
        args = [ "--stdio" ];
        extensionToLanguage = { ".py" = "python"; ".pyi" = "python"; };
      };
      typescript = {
        command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
        };
      };
      terraform = {
        command = "${pkgs.terraform-ls}/bin/terraform-ls";
        args = [ "serve" ];
        extensionToLanguage = { ".tf" = "terraform"; ".tfvars" = "terraform"; };
      };
      nix = {
        command = "${pkgs.nixd}/bin/nixd";
        args = [ ];
        extensionToLanguage = { ".nix" = "nix"; };
        initializationOptions = {
          nixpkgs = { expr = "import <nixpkgs> {}"; };
        };
      };
    };

    # Extra packages
    extraPackages = [
      # Playwright MCP wrapper script that fixes browser path issues
      (pkgs.writeShellScriptBin "mcp-server-playwright-wrapper" ''
        export PWMCP_PROFILES_DIR_FOR_TEST="$HOME/.pwmcp-profiles"
        exec ${pkgs.playwright-mcp}/bin/mcp-server-playwright \
          --executable-path "${pkgs.google-chrome}/bin/google-chrome-stable" \
          --browser chrome \
          "$@"
      '')
    ];
  };
}
