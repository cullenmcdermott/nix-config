{
  config,
  lib,
  superpowers,
  pkgs,
  ...
}:
let
  ompAgentDir = "${config.xdg.configHome}/omp/agent";

  superPowersSkillNames = [
    "brainstorming"
    "dispatching-parallel-agents"
    "executing-plans"
    "finishing-a-development-branch"
    "receiving-code-review"
    "requesting-code-review"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "using-git-worktrees"
    "using-superpowers"
    "verification-before-completion"
    "writing-plans"
    "writing-skills"
  ];

  superPowersSkillFiles = builtins.listToAttrs (
    map (skill: {
      name = "omp/agent/skills/${skill}";
      value = {
        source = "${superpowers}/skills/${skill}";
        recursive = true;
      };
    }) superPowersSkillNames
  );

  ompSessionDir = "${config.xdg.stateHome}/omp/sessions";

  ompAgentsMd = ''
    ## Environment
    This is a Nix-managed system (nix-darwin + home-manager). All packages are declaratively managed.
    - **Never install packages imperatively** — do not use `brew install`, `npm install -g`, `pip install`, `cargo install`, `go install`, or `apt-get`. If a tool is needed permanently, tell the user to add it to their Nix config.
    - **For one-off commands**, use `nix run nixpkgs#<package>` (e.g. `nix run nixpkgs#cowsay -- hello`).
    - **For temporary shell sessions** with a package, use `nix shell nixpkgs#<package>`.
    - **To search for packages**, use `nix search nixpkgs <query>`.
    - Do not assume a tool is available unless it is listed below or you have verified it exists on the system.

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
    - When performing complex logic, write a script (preferably in python or go) and run it rather than trying to cram everything into a single shell pipeline.

    ## Available CLI Tools
    Prefer these over traditional alternatives where practical (e.g. use `sd` not `sed`, `difft` not `diff`, `rg` not `grep`, `fd` not `find`, `bat` not `cat`):
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

  opencodeGoModels = [
    { id = "kimi-k2.6"; name = "Kimi K2.6"; contextWindow = 128000; maxTokens = 16384; reasoning = true; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "kimi-k2.5"; name = "Kimi K2.5"; contextWindow = 128000; maxTokens = 16384; reasoning = true; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "glm-5.1"; name = "GLM-5.1"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "glm-5"; name = "GLM-5"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "deepseek-v4-pro"; name = "DeepSeek V4 Pro"; contextWindow = 128000; maxTokens = 16384; reasoning = true; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "deepseek-v4-flash"; name = "DeepSeek V4 Flash"; contextWindow = 128000; maxTokens = 16384; reasoning = true; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "qwen3.6-plus"; name = "Qwen 3.6 Plus"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "qwen3.5-plus"; name = "Qwen 3.5 Plus"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "mimo-v2-pro"; name = "MiMo V2 Pro"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "mimo-v2-omni"; name = "MiMo V2 Omni"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "mimo-v2.5-pro"; name = "MiMo V2.5 Pro"; contextWindow = 128000; maxTokens = 16384; reasoning = false; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
    { id = "minimax-m2.7"; name = "MiniMax M2.7"; contextWindow = 100000; maxTokens = 16384; reasoning = true; cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; }; }
  ];

  # Settings for omp — note: omp uses nested style (theme.dark, theme.light) instead of flat "theme"
  # pi-web-access is NOT needed — omp has built-in web_search, fetch, and browser tools
  ompSettings = {
    sessionDir = ompSessionDir;
    # omp uses nested theme config: { dark = "tokyonight-storm"; light = "..."; }
    theme = {
      dark = "tokyonight-storm";
    };
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    defaultThinkingLevel = "high";
    defaultProvider = "github-copilot";
    defaultModel = "claude-sonnet-4.6";
    enabledModels = [
      "github-copilot/*"
      "opencode-go/*"
    ];
    providers = {
      opencode-go = {
        name = "OpenCode Go";
        baseUrl = "https://opencode.ai/zen/go/v1";
        apiKey = "!op read op://Private/OpenCode/credential";
        api = "openai-completions";
        models = opencodeGoModels;
      };
    };
  };

  ompKeybindings = {
    app.session.new = [ "ctrl+shift+n" ];
    app.session.tree = [ "ctrl+shift+t" ];
    app.session.fork = [ "ctrl+shift+f" ];
    app.session.resume = [ "ctrl+shift+r" ];
  };

  ompPresets = {
    plan = {
      description = "Read-only exploration and planning mode";
      thinkingLevel = "high";
      tools = [ "read" "grep" "find" "ls" ];
      instructions = ''
        You are in PLANNING MODE.

        Rules:
        - Do not make changes.
        - Do not use edit or write tools.
        - First understand the codebase and constraints fully.
        - Read relevant files before proposing a plan.
        - Call out risks, edge cases, and dependencies.

        Output:
        - Provide a concise implementation plan with numbered steps.
        - List the files likely to change.
        - Note any tests or validation steps that should be run.
      '';
    };

    implement = {
      description = "Focused implementation mode with normal coding tools";
      thinkingLevel = "high";
      tools = [ "read" "bash" "edit" "write" ];
      instructions = ''
        You are in IMPLEMENTATION MODE.

        Rules:
        - Keep scope tight and solve the requested task directly.
        - Read files before editing them.
        - Prefer surgical edits over broad rewrites.
        - After changes, recommend or run the most relevant validation commands when appropriate.
        - If the task expands unexpectedly, explain the issue instead of improvising a large unplanned refactor.
      '';
    };

    review = {
      description = "Code review mode focused on correctness, safety, and maintainability";
      thinkingLevel = "high";
      tools = [ "read" "bash" "grep" "find" "ls" ];
      instructions = ''
        You are in REVIEW MODE.

        Review for:
        - correctness and logic issues
        - safety and security problems
        - maintainability and architecture concerns
        - missing tests or validation gaps

        Prefer reporting concrete findings with severity, location, and an actionable fix.
      '';
    };
  };
in
{
  options.cullen.omp.enable = lib.mkEnableOption "oh-my-pi (omp) agent with Superpowers skills";

  config = lib.mkIf config.cullen.omp.enable {
    home.sessionVariables = {
      PI_CODING_AGENT_DIR = ompAgentDir;
      PI_TELEMETRY = lib.mkDefault "0";
    };

    xdg.configFile = superPowersSkillFiles // {
      # omp reads settings from $PI_CODING_AGENT_DIR/settings.json
      # Providers go in models.json (same as pi)
      "omp/agent/settings.json".text = builtins.toJSON (builtins.removeAttrs ompSettings [ "providers" ]);
      "omp/agent/models.json".text = builtins.toJSON ompSettings.providers;
      "omp/agent/keybindings.json".text = builtins.toJSON ompKeybindings;
      "omp/agent/presets.json".text = builtins.toJSON ompPresets;
      "omp/agent/AGENTS.md".text = ompAgentsMd;

      "omp/agent/extensions" = {
        source = ./omp/extensions;
        recursive = true;
      };

      "omp/agent/themes" = {
        source = ./omp/themes;
        recursive = true;
      };

      "omp/agent/prompts" = {
        source = ./../../commands;
        recursive = true;
      };

      "omp/agent/skills" = {
        source = ./../../skills;
        recursive = true;
      };
    };
  };
}