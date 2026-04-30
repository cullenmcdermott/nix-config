{
  config,
  pkgs,
  lib,
  username,
  ...
}:
let
  claudeSkills = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "f232228244495c018b3c1857436cf491ebb79bbb";
    hash = "sha256-/u7NC9opHNXh9kQMWYzeLyurdQPPHULiCTUbvTZsXeU=";
  };

  homeDirectory =
    if pkgs.stdenv.isDarwin then
      "/Users/${username}"
    else
      "/home/${username}";
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
  ];

  home.homeDirectory = lib.mkForce homeDirectory;

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
        mtime=$(stat -f %m config 2>/dev/null || echo 0)
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
  };

  # --- Claude Code Configuration (upstream home-manager module) ---
  programs.claude-code = {
    enable = true;

    settings = {
      permissions = {
        allow = [
          "Read" "Glob" "Grep" "LS" "WebFetch" "WebSearch"
          "Bash(ls:*)" "Bash(find:*)" "Bash(grep:*)" "Bash(rg:*)"
          "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)"
          "Bash(git status)" "Bash(git log:*)" "Bash(git diff:*)" "Bash(git show:*)"
          "Bash(mkdir:*)" "Bash(chmod:*)"
          "Bash(nix search:*)" "Bash(nix-env:*)" "Bash(time zsh:*)" "Bash(zsh:*)"
          "Bash(sg:*)" "Bash(ast-grep:*)" "Bash(difft:*)" "Bash(shellcheck:*)"
          "Bash(scc:*)" "Bash(yq:*)" "Bash(delta:*)" "Bash(hyperfine:*)"
          "Bash(cursor-agent:*)" "Bash(uv run:*)"
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
    '';

    skills = {
      slack-gif-creator = "${claudeSkills}/slack-gif-creator";
      skill-creator = "${claudeSkills}/skill-creator";
      frontend-design = "${claudeSkills}/skills/frontend-design";
      llm-orchestrator = ./../../skills/llm-orchestrator;
      claude-code-config = ./../../skills/claude-code-config;
    } // lib.optionalAttrs config.programs.claude-code-nix.homeAssistant.enable {
      home-assistant = ./../../skills/home-assistant;
    };

    agents = {
      external-reviewer = ./../../agents/external-reviewer.md;
      reviewer-architect = ./../../agents/reviewer-architect.md;
      reviewer-newcomer = ./../../agents/reviewer-newcomer.md;
      reviewer-perf = ./../../agents/reviewer-perf.md;
      reviewer-security = ./../../agents/reviewer-security.md;
      reviewer-stylist = ./../../agents/reviewer-stylist.md;
      reviewer-tester = ./../../agents/reviewer-tester.md;
    };

    commandsDir = ./../../commands;
  };

  programs.claude-code-nix = {
    enable = true;
    defaultModel = "claude-opus-4-7";

    mcpServers.playwright = {
      command = "mcp-server-playwright-wrapper";
      args = [ ];
      env = { };
    };

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

    extraPackages = [
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
