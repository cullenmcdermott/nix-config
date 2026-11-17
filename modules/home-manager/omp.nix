{
  config,
  lib,
  superpowers,
  pkgs,
  ...
}:
let
  ompAgentDir = "${config.xdg.configHome}/omp/agent";
  omp = pkgs.callPackage ./packages/omp.nix { };

  # Kept in lockstep with the Claude Code trim in flake-modules/modules.nix:
  # discipline skills only; planning/process skills are superseded by the
  # OpenSpec flow (skills/spec).
  superPowersSkillNames = [
    "dispatching-parallel-agents"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "using-git-worktrees"
    "verification-before-completion"
  ];

  # Build a single directory containing all skills (local + superpowers)
  # so that home-manager can symlink it cleanly without path collisions.
  allSkills = pkgs.runCommand "omp-all-skills" { } ''
    mkdir -p $out
    # Local skills from this repo (a skill dir = contains SKILL.md; skips
    # container dirs like skills/openspec, whose children are copied below)
    for d in ${./../../skills}/*; do
      [ -f "$d/SKILL.md" ] && cp -r "$d" $out/ || true
    done
    # Vendored OpenSpec skills live one level down
    for d in ${./../../skills}/openspec/openspec-*; do
      [ -f "$d/SKILL.md" ] && cp -r "$d" $out/ || true
    done
    # Superpowers skills
    for skill in ${lib.concatStringsSep " " (map (s: lib.escapeShellArg s) superPowersSkillNames)}; do
      cp -r "${superpowers}/skills/$skill" $out/
    done
  '';

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

  # Settings for omp — note: omp uses nested style (theme.dark) instead of flat "theme".
  # pi-web-access is NOT needed — omp has built-in web_search, fetch, and browser tools.
  ompSettings = {
    theme = {
      dark = "tokyonight-storm";
    };
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    defaultThinkingLevel = "high";
    defaultProvider = "homelab";
    defaultModel = "glm-5.3-flash";
    enabledModels = [
      "homelab/*"
      "github-copilot/*"
    ];
    setupVersion = 1; # omp writes this on first run if missing
  };

  # Homelab vLLM (GLM on the Sparks). Models come from /v1/models at runtime;
  # discovery is cached, so run `omp --list-models homelab` after a model is
  # added. Later: baseUrl https://llm.cullen.rocks/v1 with a per-user key.
  ompModels = {
    providers.homelab = {
      baseUrl = "https://gb10.cullen.rocks/v1";
      api = "openai-completions";
      apiKey = "HOMELAB_LLM_API_KEY"; # env var name; set in ~/.env
      discovery.type = "openai-models-list";
      # omp ignores vLLM's max_model_len. The KV pool (~664K tokens) is shared
      # by up to 4 sequences, so cap a session at 200K.
      modelOverrides."glm-5.3-flash" = {
        reasoning = true;
        contextWindow = 200000;
      };
    };
  };

  # When these exist, omp keeps its DBs, sessions and logs there instead of
  # ~/.config/omp, so Claude Code's sandbox can allow them without allowing
  # omp's config/extensions dir (code there runs unsandboxed later).
  ompStateDirs = map (d: "${d}/omp") [
    config.xdg.dataHome
    config.xdg.stateHome
    config.xdg.cacheHome
  ];

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
      tools = [
        "read"
        "grep"
        "find"
        "ls"
      ];
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
      tools = [
        "read"
        "bash"
        "edit"
        "write"
      ];
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
      tools = [
        "read"
        "bash"
        "grep"
        "find"
        "ls"
      ];
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
    home.packages = [ omp ];

    home.sessionVariables = {
      PI_CODING_AGENT_DIR = ompAgentDir;
      # PI_CONFIG_DIR makes getConfigDirName() return ".config/omp" so that native
      # extension discovery scans ~/.config/omp/agent/extensions/ instead of the
      # default ~/.omp/agent/extensions/ which does not exist on this system.
      PI_CONFIG_DIR = lib.strings.removePrefix "${config.home.homeDirectory}/" "${config.xdg.configHome}/omp";
      PI_TELEMETRY = lib.mkDefault "0";
    };

    # Plain writable files (JSON is valid YAML), regenerated every switch so Nix
    # stays authoritative. Shipping settings.json/models.json instead makes omp
    # migrate them on first run, which fails inside Claude Code's sandbox.
    home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArgs ompStateDirs}
      run install -m644 ${pkgs.writeText "omp-config.yml" (builtins.toJSON ompSettings)} "${ompAgentDir}/config.yml"
      run install -m644 ${pkgs.writeText "omp-models.yml" (builtins.toJSON ompModels)} "${ompAgentDir}/models.yml"
      run rm -f "${ompAgentDir}/settings.json.bak"
    '';

    # Homelab workers for Claude Code (mirrored to Codex/OpenCode). Lives here,
    # not in the shared modules, so hosts without omp (work laptop) don't get it.
    programs.claude-code.skills.homelab-models = ./../../skills/homelab-models;
    programs.claude-code.context = ''
      ## Homelab models
      Local tier (homelab GPUs, free, via omp): worker = homelab/glm-5.3-flash.
      Use it when the user asks for GLM or a local/homelab model; see the
      `homelab-models` skill.
    '';

    # Lets Claude Code run omp workers inside its sandbox.
    programs.claude-code.settings.sandbox = {
      network.allowedDomains = [
        "gb10.cullen.rocks"
        "llm.cullen.rocks"
      ];
      filesystem.allowWrite = ompStateDirs;
    };

    xdg.configFile = {

      "omp/agent/keybindings.json".text = builtins.toJSON ompKeybindings;
      "omp/agent/presets.json".text = builtins.toJSON ompPresets;
      "omp/agent/AGENTS.md".text = ompAgentsMd;

      "omp/agent/themes" = {
        source = ./omp/themes;
        recursive = true;
      };

      "omp/agent/prompts" = {
        source = ./../../commands;
        recursive = true;
      };

      "omp/agent/skills" = {
        source = allSkills;
        recursive = true;
      };
    };
  };
}
