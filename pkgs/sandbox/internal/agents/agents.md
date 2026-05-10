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
