{
  config,
  pkgs,
  lib,
  ...
}:
let
  claudeSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "f232228244495c018b3c1857436cf491ebb79bbb";
    hash = "sha256-/u7NC9opHNXh9kQMWYzeLyurdQPPHULiCTUbvTZsXeU=";
  };
  # google-chrome isn't packaged for aarch64-linux, so fall back to chromium
  # there (keeps the playwright-mcp wrapper working on the arm64 sandbox VM).
  browser =
    if pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64 then
      {
        pkg = pkgs.chromium;
        bin = "chromium";
        channel = "chromium";
      }
    else
      {
        pkg = pkgs.google-chrome;
        bin = "google-chrome-stable";
        channel = "chrome";
      };
  # Render an agent definition with the configured model tiers substituted for
  # the @WEAK_MODEL@/@STRONG_MODEL@ placeholders in its frontmatter. Returns
  # the content as a string — programs.claude-code.agents maps strings to
  # home.file.text (a derivation or path would be linked unsubstituted).
  tieredAgent =
    path:
    builtins.replaceStrings
      [ "@WEAK_MODEL@" "@STRONG_MODEL@" ]
      [
        config.cullen.ai.models.anthropic.weak
        config.cullen.ai.models.anthropic.strong
      ]
      (builtins.readFile path);
in
{
  imports = [
    ./base.nix
    ./shell.nix
    ./dev-packages.nix
    ./nvim
    ./packages
    ./claude-code.nix
    ./zwift-media.nix
    ./omp.nix
    ./ai-models.nix
  ];

  cullen.ai.enable = true;

  # HA-specific zsh init — depends on programs.claude-code-nix.homeAssistant
  # (claude-code.nix is imported above, so config is available here)
  programs.zsh.initContent = lib.mkIf config.programs.claude-code-nix.homeAssistant.enable (
    let
      repo = config.programs.claude-code-nix.homeAssistant.repoPath;
    in
    lib.mkAfter ''
      # ha-claude: launch Claude Code in the Home Assistant config repo.
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
        mtime=$(date -r config +%s 2>/dev/null || echo 0)
        age=$(( now - mtime ))
        if (( age > 3600 )); then
          printf "ha-claude: config is %dm stale — make pull? [Y/n] " $(( age / 60 ))
          read -r reply
          if [[ -z $reply || $reply == [Yy]* ]]; then
            make pull || echo "ha-claude: make pull failed, continuing anyway" >&2
          fi
        fi
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
  );

  # --- Claude Code Configuration (upstream home-manager module) ---
  programs.claude-code = {
    enable = true;

    settings = {
      permissions = {
        allow = [
          "Read"
          "Glob"
          "Grep"
          "LS"
          "WebFetch"
          "WebSearch"
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
          "Bash(nix search:*)"
          "Bash(nix-env:*)"
          "Bash(time zsh:*)"
          "Bash(zsh:*)"
          "Bash(sg:*)"
          "Bash(ast-grep:*)"
          "Bash(difft:*)"
          "Bash(shellcheck:*)"
          "Bash(scc:*)"
          "Bash(yq:*)"
          "Bash(delta:*)"
          "Bash(hyperfine:*)"
          "Bash(cursor-agent:*)"
          "Bash(uv run:*)"
        ];
      };
      effortLevel = "high";
      # Required for `ultracode` effort level (multi-agent dynamic workflows)
      # and for the claude-security plugin below, which is workflow-driven.
      enableWorkflows = true;

      # Marketplace plugins are declared here instead of being installed with
      # `/plugin install`, so a rebuild reasserts them. `claude-plugins-official`
      # is auto-registered on first *interactive* launch; declaring it makes a
      # fresh machine work non-interactively too.
      extraKnownMarketplaces = {
        claude-plugins-official = {
          source = {
            source = "github";
            repo = "anthropics/claude-plugins-official";
          };
        };
      };
      # Keys are `<plugin>@<marketplace>`. Plugin *contents* are fetched and
      # auto-updated by Claude Code, not pinned by Nix — only the intent to
      # have them enabled is declarative.
      enabledPlugins = {
        # `/claude-security` — on-demand multi-agent vulnerability scan of the
        # repo or working diff, then reviewed patch suggestions. Public beta as
        # of 2026-07-22. Needs enableWorkflows (above) plus python3 and git on
        # PATH; python3 comes from dev-packages.nix. Tokens count against plan.
        "claude-security@claude-plugins-official" = true;
      };
      interactiveMode = true;
      autoCompact = false;
      # Flicker-free alt-screen TUI renderer (equivalent to /tui fullscreen).
      tui = "fullscreen";
      # Binary is managed by the Homebrew `claude-code@latest` cask; disable the
      # built-in self-updater so it doesn't fight the cask-installed version.
      autoUpdates = false;
      # Commit trailer is added manually (see context below); don't auto-append
      # a second `Co-authored-by: Claude` line.
      includeCoAuthoredBy = false;
      # File checkpoints for /rewind (undo of Claude's edits).
      fileCheckpointingEnabled = true;
      # Ring the terminal bell when Claude finishes / goes idle (Ghostty).
      preferredNotifChannel = "terminal_bell";
      sandbox = {
        enabled = true;
        autoAllowBashIfSandboxed = true;
      };
    };

    context = ''
      ## Environment
      This is a Nix-managed system (nix-darwin + home-manager). All packages are declaratively managed.
      - **Never install packages imperatively** — do not use `brew install`, `npm install -g`, `pip install`, `cargo install`, `go install`, or `apt-get`. If a tool is needed permanently, tell the user to add it to their Nix config.
      - **For one-off commands**, use `nix run nixpkgs#<package>` (e.g., `nix run nixpkgs#cowsay -- hello`).
      - **For temporary shell sessions** with a package, use `nix shell nixpkgs#<package>`.
      - **To search for packages**, use `nix search nixpkgs <query>`.
      - Do not assume a tool is available unless it is listed below or you have verified it exists on the system.
      - **LSP servers are Nix-managed.** Do not install LSP plugins from the Claude Code marketplace. All language server configuration is declarative via the `programs.claude-code-nix.lsp.servers` option.
      - **Marketplace plugins are Nix-managed.** Do not run `/plugin install`; add the plugin to `programs.claude-code.settings.enabledPlugins` (and `extraKnownMarketplaces` if it is not from the official marketplace) and rebuild.

      ## Sandbox Awareness
      - If a command fails with unexpected "permission denied", TLS errors, or connection refused, it is likely a sandbox restriction. Retry the command outside the sandbox before investigating other causes.

      ## Verify Before Claiming
      - Always verify state with actual commands before making claims. Do not assert that code isn't pushed, tags don't exist, or services aren't running without checking first. When debugging, form hypotheses and test them with commands — do not state assumptions as fact.

      ## Destructive Changes
      - Before removing, deleting, or cleaning up resources, confirm the replacement is fully working first. Never prematurely remove old infrastructure during migrations. For multi-step migrations: deploy new -> migrate data -> verify -> clean up old, with confirmation at each gate.

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

    ''
    # Model-tier delegation policy — rendered from cullen.ai.models (ai-models.nix).
    + config.cullen.ai.claudeDelegationPolicy;

    skills = {
      slack-gif-creator = "${claudeSkills}/slack-gif-creator";
      skill-creator = "${claudeSkills}/skill-creator";
      frontend-design = "${claudeSkills}/skills/frontend-design";
      llm-orchestrator = ./../../skills/llm-orchestrator;
      claude-code-config = ./../../skills/claude-code-config;
      delegation = ./../../skills/delegation;
      spec = ./../../skills/spec;
      # Vendored OpenSpec-generated skills (see skills/openspec/README.md for
      # the regeneration procedure). Paired with commands/opsx/ for /opsx:*.
      openspec-propose = ./../../skills/openspec/openspec-propose;
      openspec-apply-change = ./../../skills/openspec/openspec-apply-change;
      openspec-archive-change = ./../../skills/openspec/openspec-archive-change;
      openspec-explore = ./../../skills/openspec/openspec-explore;
      openspec-sync-specs = ./../../skills/openspec/openspec-sync-specs;
    }
    // lib.optionalAttrs config.programs.claude-code-nix.homeAssistant.enable {
      home-assistant = ./../../skills/home-assistant;
    };

    agents = {
      builder = tieredAgent ./../../agents/builder.md;
      external-reviewer = ./../../agents/external-reviewer.md;
      reviewer-architect = ./../../agents/reviewer-architect.md;
      reviewer-newcomer = ./../../agents/reviewer-newcomer.md;
      reviewer-perf = tieredAgent ./../../agents/reviewer-perf.md;
      reviewer-security = ./../../agents/reviewer-security.md;
      reviewer-stylist = tieredAgent ./../../agents/reviewer-stylist.md;
      reviewer-tester = tieredAgent ./../../agents/reviewer-tester.md;
    };

    commandsDir = ./../../commands;
  };

  programs.claude-code-nix = {
    enable = true;
    # Passed as --model on every alias launch, so /model inside a session is
    # session-only by design — this line always wins for new sessions.
    defaultModel = "claude-opus-5";

    mcpServers.playwright = {
      command = "mcp-server-playwright-wrapper";
      args = [ ];
      env = { };
    };

    lsp.servers = {
      go = {
        command = "${pkgs.gopls}/bin/gopls";
        args = [ "serve" ];
        extensionToLanguage = {
          ".go" = "go";
        };
      };
      python = {
        command = "${pkgs.pyright}/bin/pyright-langserver";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".py" = "python";
          ".pyi" = "python";
        };
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
        extensionToLanguage = {
          ".tf" = "terraform";
          ".tfvars" = "terraform";
        };
      };
      nix = {
        command = "${pkgs.nixd}/bin/nixd";
        args = [ ];
        extensionToLanguage = {
          ".nix" = "nix";
        };
        initializationOptions = {
          nixpkgs = {
            expr = "import <nixpkgs> {}";
          };
        };
      };
      yaml = {
        command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".yml" = "yaml";
          ".yaml" = "yaml";
        };
      };
      bash = {
        command = "${pkgs.bash-language-server}/bin/bash-language-server";
        args = [ "start" ];
        extensionToLanguage = {
          ".sh" = "shellscript";
          ".bash" = "shellscript";
        };
      };
      dockerfile = {
        command = "${pkgs.dockerfile-language-server}/bin/docker-langserver";
        args = [ "--stdio" ];
        extensionToLanguage = {
          "Dockerfile" = "dockerfile";
          ".dockerfile" = "dockerfile";
        };
      };
      json = {
        command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".json" = "json";
          ".jsonc" = "jsonc";
        };
      };
    };

    extraPackages = [
      # OpenSpec CLI — backs the vendored openspec-* skills and the `spec`
      # wrapper skill. nixpkgs has 1.4.1; the store feature (planning repos
      # outside the code repo) needs >= 1.5.0, which lands with nixpkgs PR
      # #538904 — after it merges, a nixpkgs flake update picks it up from
      # the binary cache. Building it from source locally does not work:
      # pnpm's node worker threads hit an fd-reuse race with macOS guarded
      # fds under the nix-daemon (EXC_GUARD SIGKILL), so we wait for Hydra.
      pkgs.openspec

      (pkgs.writeShellScriptBin "mcp-server-playwright-wrapper" ''
        export PWMCP_PROFILES_DIR_FOR_TEST="$HOME/.pwmcp-profiles"
        exec ${pkgs.playwright-mcp}/bin/mcp-server-playwright \
          --executable-path "${browser.pkg}/bin/${browser.bin}" \
          --browser ${browser.channel} \
          "$@"
      '')
    ];
  };
}
