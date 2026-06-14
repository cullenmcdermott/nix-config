## Sandbox Environment

You are running inside a disposable sandbox VM (Ubuntu 24.04 arm64) that exists
solely for your use — you have full autonomy here. The VM is isolated from the
host, with three deliberate exceptions you must respect:

- The **project directory** is a two-way sync: anything you write there lands on
  the host's real working tree.
- Your **credentials** (`~/.claude`, `~/.codex` auth) persist back to the host.
- Any **writable host mounts** listed below affect the host directly.

Outside those paths, nothing you do here touches the host. But treat writes to
the project directory and destructive git/filesystem actions there with the same
care you would on the host machine itself — confirm with the user first.

### Package Management

**Flox** is the primary package manager. It wraps Nix with a simpler interface.

- **Install packages**: `flox install <package>` (e.g. `flox install ripgrep`)
- **Search packages**: `flox search <query>`
- **One-off commands**: `nix run nixpkgs#<package> -- <args>` (e.g. `nix run nixpkgs#cowsay -- hello`)
- **Temporary shell**: `nix shell nixpkgs#<package>`
- `apt-get` is available but prefer Flox/Nix — the Nix package set is larger and more current.
- Do not use `brew` (not available), `npm install -g`, `pip install`, or `cargo install` for system tooling. Use Flox.

### Flox Environments

The project's flox environment (if one exists) is activated automatically when
you start. If you navigate into a subdirectory that has its own `.flox/`
directory, you should activate that project's environment:

```bash
# Check if the current directory has its own flox environment
if [ -d .flox ]; then
  eval "$(flox activate)"
fi
```

This ensures you always have the correct toolchain, dependencies, and
environment variables for the project you are working in. Watch for `.flox/`
directories when changing into new project roots.

### Bridge to Host

A bridge daemon connects this VM to the host machine via a Unix socket at
`/run/sandbox/bridge.sock`. Two host operations are exposed inside the VM as
thin shims:

- `op read op://<vault>/<item>/<field>` — forwarded to the host's 1Password
  CLI. Only `op read` is supported; every other `op` subcommand exits non-zero.
  The host enforces an allowlist (`bridge.op_allow` in
  `~/.config/sandbox/config.toml`). A denied read returns an error that names
  the missing pattern; do not retry — report it to the user so they can update
  their allowlist.
- `xdg-open <https-url>` — opens the URL in the host's default browser. Only
  `http://` and `https://` URLs are accepted.

### Git

Whether `.git` syncs into the VM is a per-VM setting (`sync_git` in the host's
per-VM config; off by default). Check the actual state before assuming: run
`git rev-parse --git-dir` in the project directory.

- **If it succeeds**: git works normally, and commits/branches sync back to
  the host two-way. Avoid long-running rebases or other heavy ref/index
  churn while the user might also be running git on the host — concurrent
  git activity on both sides can cause Mutagen conflicts.
- **If it fails**: `.git` is excluded from sync. Do not attempt git commits,
  branches, or history inspection; they will fail. Describe the changes you
  made so the user can commit on the host.

### Key Paths

- **Project directory**: mounted at the same absolute path as on the host (Mutagen sync, writable)
- **~/.claude/**: partially overlaid from the host (skills, commands, agents, hooks are read-only mounts from host); other files (credentials, config) are local to the VM
- **/etc/sandbox/AGENTS.md**: this file

### What to Expect

- The VM is ephemeral. It can be destroyed and recreated at any time. Do not store important state outside the synced project directory.
- Network access is available. You can curl, fetch dependencies, clone repos.
- Nix daemon is running. Nix builds and `nix run` work.
- You have passwordless `sudo`.

### Verify Before Claiming

- Always verify state with actual commands before making claims.
- When debugging, form hypotheses and test them — do not state assumptions as fact.
