{
  config,
  lib,
  ...
}:
let
  piAgentDir = "${config.xdg.configHome}/pi/agent";
  piSessionDir = "${config.xdg.stateHome}/pi/sessions";

  piAgentsMd = ''
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

  piSettings = {
    sessionDir = piSessionDir;
    theme = "tokyonight-storm";
    enableInstallTelemetry = false;
    enableSkillCommands = true;
    defaultThinkingLevel = "high";
    enabledModels = [
      "claude-*"
      "gpt-*"
      "gemini-*"
    ];
  };

  piKeybindings = {
    app.session.new = [ "ctrl+shift+n" ];
    app.session.tree = [ "ctrl+shift+t" ];
    app.session.fork = [ "ctrl+shift+f" ];
    app.session.resume = [ "ctrl+shift+r" ];
  };

  piPresets = {
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
  home.sessionVariables = {
    PI_CODING_AGENT_DIR = piAgentDir;
    PI_TELEMETRY = lib.mkDefault "0";
  };

  xdg.configFile."pi/agent/settings.json".text = builtins.toJSON piSettings;
  xdg.configFile."pi/agent/keybindings.json".text = builtins.toJSON piKeybindings;
  xdg.configFile."pi/agent/presets.json".text = builtins.toJSON piPresets;
  xdg.configFile."pi/agent/AGENTS.md".text = piAgentsMd;

  xdg.configFile."pi/agent/extensions" = {
    source = ./pi/extensions;
    recursive = true;
  };

  xdg.configFile."pi/agent/themes" = {
    source = ./pi/themes;
    recursive = true;
  };

  xdg.configFile."pi/agent/prompts" = {
    source = ./../../commands;
    recursive = true;
  };

  xdg.configFile."pi/agent/skills" = {
    source = ./../../skills;
    recursive = true;
  };
}
