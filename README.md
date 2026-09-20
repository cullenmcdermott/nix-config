# system-config

Cullen's multi-platform Nix configuration: a [flake-parts](https://flake.parts)
flake that builds a macOS host with [nix-darwin](https://github.com/nix-darwin/nix-darwin)
+ [home-manager](https://github.com/nix-community/home-manager), and portable
standalone home-manager configs for Linux machines, containers, and the sandbox VM.

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` | Inputs and flake-parts wiring |
| `flake-modules/modules.nix` | Public module exports + the `mkHome` factory and `homeConfigurations` |
| `flake-modules/per-system.nix` | Per-system packages, formatter, checks |
| `flake-modules/sandbox.nix` | Sandbox CLI packaging glue |
| `hosts/cullens-macbook-pro/` | The macOS `darwinConfiguration` |
| `modules/darwin/` | nix-darwin modules (defaults, homebrew, GC) |
| `modules/home-manager/` | home-manager modules, profiles, dotfiles |
| `pkgs/claude-statusline/` | The native Claude statusline binary |
| `sandbox` flake input | The remotely pinned CLI for Kubernetes agent sessions |
| `distrobox-setup.sh` | Bootstrap a distrobox container's home-manager |

## macOS host

The host config is `darwinConfigurations."cullens-MacBook-Pro"`. Two shell
aliases (defined in `modules/home-manager/shell.nix`) wrap the rebuild:

```bash
nixswitch   # sudo darwin-rebuild switch --flake ~/src/system-config#
nixup       # nix flake update, then nixswitch
```

### Fresh machine bootstrap

```bash
# 1. Install Nix (Determinate Systems installer recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Clone this repo
git clone https://github.com/cullenmcdermott/system-config ~/src/system-config

# 3. First build (alias isn't on PATH yet)
sudo nix run nix-darwin -- switch --flake ~/src/system-config#cullens-MacBook-Pro

# subsequent rebuilds: just `nixswitch`
```

The sandbox CLI is pinned to a GitHub commit; no separate local checkout is
required. Access to its repository is required when fetching it.

For the first build, set `cullen.linuxBuilder.tuned = false` in the host config
so the stock Linux builder can come from the binary cache. Once that builder
is running, restore `true` and rebuild to enable the tuned VM.

## Shared coding agents

`modules/home-manager/ai-models.nix` shares the Nix-declared Claude skill
catalog (including Flox/Superpowers), global instructions, and MCP definitions
with Codex and OpenCode. Add skills through `programs.claude-code.skills` and
servers through `programs.claude-code-nix.mcpServers`. Ponytail uses one pinned
source across all three; its always-on instruction replaces the Claude plugin.
Claude-specific agents, commands, LSP plugins, and provider-supplied tools remain
harness-specific. MCP authentication is separate in each harness.

Codex defaults to “approve for me”: `approval_policy = "on-request"`,
`approvals_reviewer = "auto_review"`, and `sandbox_mode = "workspace-write"`.
Activation merges those settings into writable TOML, preserving runtime model,
trust, UI settings, and unrelated MCP entries. OpenCode's generated
`opencode.json` is merged with its existing runtime `opencode.jsonc`.

The shared `delegation` skill calls `codex exec`, `claude --print`, or
`opencode run` directly for implementation and peer review. Child sessions need
an explicit task/context handoff and use their own harness permissions; they
must never be used to bypass a parent's denial. Blocked work returns to the
parent's approval process. No delegation service or wrapper is required.

## Portable Linux / standalone home-manager

Non-darwin machines use standalone home-manager configs produced by the
`mkHome` factory in `flake-modules/modules.nix`. Pick the entry matching the
machine's architecture and run:

```bash
nix run home-manager -- switch -b backup --flake ~/src/system-config#cullen@x86_64-linux
# or  ...#cullen@aarch64-linux
```

Defined `homeConfigurations`:

| Name | System | Profile |
|---|---|---|
| `cullen@x86_64-linux` | x86_64-linux | workstation |
| `cullen@aarch64-linux` | aarch64-linux | workstation |
| `vm` | aarch64-linux | vm (workstation + agentic skills) |

> google-chrome has no aarch64-linux build, so the workstation profile
> transparently falls back to chromium on that platform.

Darwin rebuild aliases are only installed on macOS. Shell startup does not
activate a home Flox environment; activate project environments explicitly.

### distrobox

On an immutable host (e.g. Bazzite) run the bootstrap script inside a container
to install Nix and activate the matching home-manager config:

```bash
./distrobox-setup.sh
```

It derives the config name from the container's user and architecture
(`<user>@<arch>-linux`) and points at `~/src/system-config`.

## Adding a new device

- **Another Linux box / user:** add an entry to `flake.homeConfigurations` in
  `flake-modules/modules.nix`:

  ```nix
  "alice@x86_64-linux" = mkHome {
    username = "alice";
    system = "x86_64-linux";
    # profile ? workstation;  modules ? [ ];  homeDirectory ? auto
  };
  ```

- **Another Mac:** add a `hosts/<name>/default.nix` defining a new
  `darwinConfigurations.<hostname>` and import it from `flake.nix`.

## Downstream flakes

Public modules are exported under `darwinModules.*` and `homeManagerModules.*`
(and the factory as `lib.mkHome`). A consumer flake can import them directly —
optional modules close over this flake's own inputs (flox, dagger, superpowers,
etc.) so consumers don't need to declare them locally.

## Formatting & checks

```bash
nix fmt                              # nixfmt-rfc-style (the declared formatter)
nix run nixpkgs#deadnix -- .         # dead-code lint
nix run nixpkgs#statix -- check .    # idiom lint
nix flake check                      # build host + home configs
```
