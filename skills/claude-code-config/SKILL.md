---
name: claude-code-config
description: Use this skill when helping manage Claude Code configuration, including settings, MCP servers, LSP servers, skills, hooks, permissions, plugins, or per-device overrides. Also use when the user asks about Claude Code features, marketplace skills, or wants to modify their setup.
---

# Claude Code Configuration Manager

## Overview

This system uses a **declarative Nix home-manager module** (`programs.claude-code`) to manage all Claude Code configuration. Files under `~/.claude/` are Nix-managed symlinks to the Nix store and must NOT be edited directly.

## Architecture

Two modules work together:
- **`programs.claude-code`** (upstream home-manager) — settings, skills, agents, commands, hooks, mcpServers, memory (CLAUDE.md), rules
- **`programs.claude-code-nix`** (our custom module) — LSP servers with Nix store paths, statusline scripts, shell aliases, extra packages

```
flake.nix
  └─ modules/home-manager/default.nix    # Option VALUES for both modules
       ├─ programs.claude-code (upstream)
       │    └─ Generates: ~/.claude/settings.json
       │                  ~/.claude/CLAUDE.md
       │                  ~/.claude/skills/*/
       │                  ~/.claude/agents/
       │                  ~/.claude/commands/
       └─ programs.claude-code-nix (our module: claude-code.nix)
            └─ Generates: ~/.claude/statusline-command.sh
                          ~/.claude/custom-plugins/lsp-servers/.lsp.json
                          Shell aliases (claude, clod)
```

### Key Files

| File | Purpose |
|------|---------|
| `modules/home-manager/claude-code.nix` | Our Nix extensions module (LSP, statusline, aliases) |
| `modules/home-manager/default.nix` | Where ALL option values are set |
| `modules/home-manager/packages/claude-code.nix` | Claude Code binary package derivation |
| `flake.nix` | System composition — `extraHomeManagerModules` for per-device overrides |
| `systems/work/claude-code.nix` | Work laptop override template |
| `skills/` | Custom skill sources (home-assistant, llm-orchestrator, claude-code-config) |
| `agents/` | Sub-agent definitions for multi-model review |
| `commands/` | Custom command definitions |

## How To: Common Operations

### Add an MCP Server

In `modules/home-manager/default.nix`, add to `programs.claude-code.mcpServers`:

```nix
programs.claude-code.mcpServers.my-server = {
  command = "mcp-server-my-thing";
  args = [ "--flag" "value" ];
  env = { MY_VAR = "value"; };
};
```

Then rebuild: `nixswitch`

### Add an LSP Server

In `modules/home-manager/default.nix`, add to `programs.claude-code-nix.lsp.servers`:

```nix
programs.claude-code-nix.lsp.servers.rust = {
  command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
  args = [ ];
  extensionToLanguage = { ".rs" = "rust"; };
};
```

Always use absolute Nix store paths (`${pkgs.foo}/bin/foo`) for the command.

### Add a Permission

In `modules/home-manager/default.nix`, add to `programs.claude-code.settings.permissions.allow`:

```nix
programs.claude-code.settings.permissions.allow = [
  # ... existing permissions ...
  "Bash(my-new-command:*)"
];
```

### Add a Skill

1. Create the skill directory at `skills/<skill-name>/SKILL.md`
2. In `modules/home-manager/default.nix`, add to `programs.claude-code.skills`:

```nix
programs.claude-code.skills.my-skill = ./../../skills/my-skill;
```

Skills can be directories (with SKILL.md inside) or inline strings.

### Disable a Skill on a Specific Device

In a per-device override module (e.g., `systems/work/claude-code.nix`):

```nix
programs.claude-code.skills.home-assistant = lib.mkForce "";
```

### Add Hooks

In `modules/home-manager/default.nix`:

```nix
programs.claude-code.settings.hooks = {
  PreToolUse = [
    {
      type = "command";
      command = "my-hook-script";
      matcher = "Bash(rm *)";
    }
  ];
};
```

### Override Config for Work Device

1. Edit `systems/work/claude-code.nix` with work-specific overrides
2. In `flake.nix`, add it to the work system's `extraHomeManagerModules`:

```nix
darwinConfigurations."work-macbook" = mkDarwinConfig {
  username = "cullen";
  system = "aarch64-darwin";
  hostname = "work-macbook";
  extraHomeManagerModules = [ ./systems/work/claude-code.nix ];
};
```

The Nix module system merges lists (permissions), attrsets (MCP servers, LSP, skills), and strings (memory) automatically.

### Update Claude Code Package Version

In `modules/home-manager/packages/claude-code.nix`, update the `version` and `platformHashes`. Or override via the module:

```nix
programs.claude-code.package = pkgs.callPackage ./packages/claude-code.nix {
  version = "2.2.0";
  platformHashes = { ... };
};
```

### Search for Marketplace Skills

Use WebFetch to browse the Claude Code plugin marketplace:
- Marketplace: `https://api.anthropic.com/mcp-registry/docs`
- Official skills repo: `https://github.com/anthropics/skills`

### Look Up Latest Claude Code Docs

Fetch these URLs for up-to-date documentation:
- Settings: `https://docs.anthropic.com/en/docs/claude-code/settings`
- Plugins: `https://docs.anthropic.com/en/docs/claude-code/plugins`
- Hooks: `https://docs.anthropic.com/en/docs/claude-code/hooks`
- Skills: `https://docs.anthropic.com/en/docs/claude-code/skills`
- MCP: `https://docs.anthropic.com/en/docs/claude-code/mcp`

## Anti-Patterns (Do NOT Do These)

1. **Never edit `~/.claude/settings.json` directly** — it's a read-only Nix symlink. Use `programs.claude-code.settings.*` options instead.
2. **Never run `claude plugins install` for LSP plugins** — LSP is Nix-managed via `programs.claude-code-nix.lsp.servers`. Marketplace LSP plugins will conflict.
3. **Never create files in `~/.claude/` manually** — use the module options. Manual files will be orphaned or overwritten by home-manager.
4. **Never use bare command names in LSP config** — always use `${pkgs.foo}/bin/foo` absolute paths to avoid PATH resolution issues.
5. **Never add skills/agents/commands directly to `~/.claude/`** — add them to the `skills/`, `agents/`, or `commands/` directories in the repo and wire them through the module.

## Module Options Reference

### `programs.claude-code` (upstream home-manager)

| Option | Type | Description |
|--------|------|-------------|
| `enable` | bool | Enable Claude Code |
| `package` | package | The claude-code package |
| `settings` | JSON attrs | Flat JSON merged into settings.json |
| `mcpServers` | attrs | MCP server definitions (wrapped into binary) |
| `memory.text` | str | CLAUDE.md content |
| `skills` | attrs of (str or path) | Skills (dirs or inline SKILL.md content) |
| `agents` / `agentsDir` | attrs or path | Agent definitions |
| `commands` / `commandsDir` | attrs or path | Command definitions |
| `hooks` / `hooksDir` | attrs or path | Hook scripts |
| `rules` / `rulesDir` | attrs or path | Rule files |
| `outputStyles` | attrs | Output style files |

### `programs.claude-code-nix` (our Nix extensions)

| Option | Type | Description |
|--------|------|-------------|
| `enable` | bool | Enable Nix extensions |
| `lsp.enable` | bool | Enable LSP plugin |
| `lsp.servers` | attrs | LSP servers with absolute Nix store paths |
| `statusLine.enable` | bool | Enable custom statusline |
| `statusLine.scriptText` | null or str | Custom script (null = default 3-line) |
| `extraPackages` | list of package | Additional packages |
