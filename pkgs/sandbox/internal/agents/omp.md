## Sandbox Environment

You are running inside an isolated, disposable sandbox VM (Ubuntu 24.04 arm64).
This VM exists solely for your use — you have full autonomy. There is no
production data and nothing you do here can affect the host system.

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
`/run/sandbox/bridge.sock`. It provides:

- **1Password secrets**: accessible via the `op` CLI (reads are forwarded to the host)
- **URL opening**: `xdg-open` or bridge-based URL opening routes to the host browser
- **Git**: the project directory is synced from the host via Mutagen; `git` operations work normally

### Key Paths

- **Project directory**: mounted at the same absolute path as on the host (Mutagen sync, writable)
- **~/.config/omp/agent/**: config root; skills, prompts, extensions, and themes are read-only mounts from host; other files (agent.db, sessions) are local to the VM
- **PI_CODING_AGENT_DIR**: env var pointing to `~/.config/omp/agent/` — set in `/etc/profile.d/omp-env.sh`
- **PI_CONFIG_DIR**: env var set to `.config/omp` — omp appends this to `$HOME` internally

### Known Gaps

- **GitHub Copilot auth**: VM-local; you must re-authenticate in each new VM. Token is stored in `agent.db` (VM-local state).
- **Session history**: stored in VM-local `~/.config/omp/agent/agent.db`; ephemeral per VM.

### What to Expect

- The VM is ephemeral. It can be destroyed and recreated at any time. Do not store important state outside the synced project directory.
- Network access is available. You can curl, fetch dependencies, clone repos.
- Nix daemon is running. Nix builds and `nix run` work.
- You have passwordless `sudo`.

### Verify Before Claiming

- Always verify state with actual commands before making claims.
- When debugging, form hypotheses and test them — do not state assumptions as fact.