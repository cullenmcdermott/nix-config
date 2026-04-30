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

  # Superpowers workflow skills
  superpowers = inputs.superpowers;

in
{
  # specify home-manager configs
  imports = [
    ./nvim
    ./packages
    ./claude-code.nix
    ./pi.nix
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
    # cmux reads terminal theme/font/colors from ghostty's config above; this
    # file controls cmux-app-level settings (telemetry, appearance, shortcuts).
    configFile."cmux/settings.json" = lib.mkIf pkgs.stdenv.isDarwin {
      text = builtins.toJSON {
        "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
        app = {
          appearance = "dark";
          sendAnonymousTelemetry = false;
        };
        browser.theme = "dark";
        shortcuts.bindings = {
          # Ctrl+Shift+HJKL for split (pane) focus navigation
          focusLeft = "ctrl+shift+h";
          focusDown = "ctrl+shift+j";
          focusUp = "ctrl+shift+k";
          focusRight = "ctrl+shift+l";
          # Cmd+Shift+JK for workspace (surface) navigation like vim
          prevSurface = "cmd+shift+j";
          nextSurface = "cmd+shift+k";
          reloadConfiguration = "cmd+shift+r";
        };
      };
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
  programs.zsh.initContent = lib.mkMerge [
    (lib.mkBefore ''
      ${builtins.readFile ./dotfiles/zshrc}
    '')
    (lib.mkIf config.programs.claude-code-nix.homeAssistant.enable (
      let
        repo = config.programs.claude-code-nix.homeAssistant.repoPath;
      in
      lib.mkAfter ''
        # ha-claude: launch Claude Code in the Home Assistant config repo.
        # - cd's into the repo so its project-local .mcp.json (ha-mcp) loads
        # - verifies HA_TOKEN is set (sourced from ~/.env earlier in this file)
        # - prompts to refresh local config from HA if it's >1h stale
        # - hands off to the `claude` alias (carries --plugin-dir and --model)
        ha-claude() {
          local repo="${repo}"
          if [[ ! -d $repo ]]; then
            echo "ha-claude: $repo does not exist" >&2
            return 1
          fi
          cd "$repo" || return 1
          if [[ -z $HA_TOKEN ]]; then
            echo "ha-claude: HA_TOKEN is not set in env (expected from ~/.env)" >&2
            return 1
          fi
          local now mtime age reply
          now=$(date +%s)
          mtime=$(stat -f %m config 2>/dev/null || echo 0)
          age=$(( now - mtime ))
          if (( age > 3600 )); then
            printf "ha-claude: config is %dm stale — make pull? [Y/n] " $(( age / 60 ))
            read -r reply
            if [[ -z $reply || $reply == [Yy]* ]]; then
              make pull || echo "ha-claude: make pull failed, continuing anyway" >&2
            fi
          fi

          # HA-themed session: launch banner, terminal title, statusline flag.
          local HA_BLUE=$'\033[38;2;24;188;242m'
          local HA_DIM=$'\033[38;2;100;160;200m'
          local RESET=$'\033[0m'
          local BOLD=$'\033[1m'
          printf '\033]0;HA Claude\007'
          printf '%s%s════════════════════════════════════════════════════════%s\n' "$HA_BLUE" "$BOLD" "$RESET"
          printf '%s🏠  Home Assistant Mode%s  %s·%s  ha-mcp + validation hooks  %s·%s  %s\n' \
            "$HA_BLUE$BOLD" "$RESET" "$HA_DIM" "$RESET" "$HA_DIM" "$RESET" "$repo"
          printf '%s%s════════════════════════════════════════════════════════%s\n\n' "$HA_BLUE" "$BOLD" "$RESET"
          CLAUDE_HA_MODE=1 claude "$@"
        }
      ''
    ))
  ];
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
  # Override to skip hanging shell-integration tests (go-1.26.2 + fish-4.6.0
  # push this derivation past what hydra has cached; tests hang in the sandbox).
  programs.direnv.package = pkgs.direnv.overrideAttrs (_: { doCheck = false; });
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
      env = {
        CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1";
      };
      effortLevel = "high";
      interactiveMode = true;
      autoCompact = false;
      sandbox = {
        enabled = true;
        autoAllowBashIfSandboxed = true;
      };
    };

    # CLAUDE.md content
    context = ''
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

      # Superpowers workflow skills (v5.0.7)
      sp-brainstorming = "${superpowers}/skills/brainstorming";
      sp-using-git-worktrees = "${superpowers}/skills/using-git-worktrees";
      sp-writing-plans = "${superpowers}/skills/writing-plans";
      sp-subagent-driven-development = "${superpowers}/skills/subagent-driven-development";
      sp-test-driven-development = "${superpowers}/skills/test-driven-development";
      sp-systematic-debugging = "${superpowers}/skills/systematic-debugging";
      sp-dispatching-parallel-agents = "${superpowers}/skills/dispatching-parallel-agents";
      sp-requesting-code-review = "${superpowers}/skills/requesting-code-review";
      sp-receiving-code-review = "${superpowers}/skills/receiving-code-review";
      sp-executing-plans = "${superpowers}/skills/executing-plans";
      sp-finishing-a-development-branch = "${superpowers}/skills/finishing-a-development-branch";
      sp-using-superpowers = "${superpowers}/skills/using-superpowers";
      sp-writing-skills = "${superpowers}/skills/writing-skills";
      sp-verification-before-completion = "${superpowers}/skills/verification-before-completion";
    } // lib.optionalAttrs config.programs.claude-code-nix.homeAssistant.enable {
      home-assistant = ./../../skills/home-assistant;
    };

    # Agents: local reviewers + superpowers code-reviewer
    agents = {
      external-reviewer = ./../../agents/external-reviewer.md;
      reviewer-architect = ./../../agents/reviewer-architect.md;
      reviewer-newcomer = ./../../agents/reviewer-newcomer.md;
      reviewer-perf = ./../../agents/reviewer-perf.md;
      reviewer-security = ./../../agents/reviewer-security.md;
      reviewer-stylist = ./../../agents/reviewer-stylist.md;
      reviewer-tester = ./../../agents/reviewer-tester.md;
      code-reviewer = "${superpowers}/agents/code-reviewer.md";
    };

    commandsDir = ./../../commands;
  };

  # --- Claude Code Nix Extensions (our custom module) ---
  programs.claude-code-nix = {
    enable = true;
    defaultModel = "claude-opus-4-7";

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
