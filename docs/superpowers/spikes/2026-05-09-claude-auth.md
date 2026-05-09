# Spike: Claude Code auth injection

**Date:** 2026-05-09
**Drives:** Phase 10 (Claude wrapper + `sandbox claude`)
**Status:** resolved

## Question
What is the minimal-trust mechanism for handing a freshly-spawned Claude Code
inside a Lima VM a working credential, given a host-side bridge that can
return the user's current token on demand?

## Findings

### Host environment

- `claude --version`: 2.1.138 (standalone Mach-O arm64 binary, not Node.js)
- Binary type: **standalone binary** (not a npm wrapper)
- Credentials file: credentials are stored in **macOS Keychain** (not
  `~/.claude/.credentials.json` as the spec assumed). The `~/.claude.json`
  contains only `oauth:tokenCache` which is a session token, not the auth
  credential itself.
- `op` (1Password CLI) is available at `/etc/profiles/per-user/cullen/bin/op`
  version 2.34.0, signed into "Private" vault.

### Auth precedence in Claude Code (from official docs)

From `https://docs.anthropic.com/en/docs/claude-code/authentication`:

1. Cloud provider (Bedrock/Vertex/Foundry) if env vars set
2. `ANTHROPIC_AUTH_TOKEN` → `Authorization: Bearer` header
3. **`ANTHROPIC_API_KEY`** → `X-Api-Key` header ← **preferred for headless**
4. `apiKeyHelper` script (shell script in `settings.json`, runs every 5 min)
5. `CLAUDE_CODE_OAUTH_TOKEN` long-lived token from `claude setup-token`
6. Subscription OAuth from `/login` (interactive browser flow)

### Mechanism 1 — Env var (`ANTHROPIC_API_KEY`)

**Result: works in both interactive and non-interactive mode**

The docs explicitly state: "API key sent as `X-Api-Key` header. When set, this key
is used instead of your Claude Pro, Max, Team, or Enterprise subscription."
In non-interactive mode (`-p`), the key is always used when present. No
credential file on disk needed; token never touches VM persistent storage.

**This is the primary mechanism.** The wrapper script in the VM:

1. Calls `bridge.claude.auth` to get `{ token, expires_at }`
2. Sets `ANTHROPIC_API_KEY=<token>` in the environment
3. `exec`s the real Claude Code binary

### Mechanism 2 — `apiKeyHelper` script

**Not needed for v1.** The `apiKeyHelper` feature exists for dynamic/rotating
credentials but adds a layer of complexity (settings.json, TTL management). Since
`ANTHROPIC_API_KEY` works cleanly for headless use, we skip this.

### Mechanism 3 — OAuth refresh via bridge (fallback if ANTHROPIC_API_KEY is insufficient)

**Not needed for v1.** The spec mentioned this as the worst case. The
`ANTHROPIC_API_KEY` path sidesteps it entirely.

## Decision

The wrapper script in Phase 10 will use **`ANTHROPIC_API_KEY` env var** because:

1. Documented and supported in headless/non-interactive mode
2. Never touches VM persistent storage (env var only, dies with the session)
3. Works with the host bridge's `claude.auth` endpoint returning the key
4. Simplest path — no credential file, no Keychain access needed from VM

## Implementation note for Phase 10

The host bridge's `claude.auth` handler (Phase 9) needs to fetch the actual
API key. Options for that handler (from most to least preferred):

1. **Read `op read op://` from 1Password** if the user stores their
   `ANTHROPIC_API_KEY` there (common pattern). This is the bridge's
   `secret.read` handler, no special endpoint needed.
2. **Read `~/.env` or `~/.anthropic.key`** if user prefers a flat file.
3. **Read from Keychain** via `security find-generic-password` on macOS.

For initial implementation, the `claude.auth` handler can read `op://` refs via
the existing `secret.read` bridge mechanism. The user stores their key in
1Password under a known path (e.g., `op://Private/Claude API Key/key`), and
the handler fetches it. **This means Phase 9's `secret.read` is the critical
dependency for Phase 10.**

## Open follow-ups

- If user does not store their key in 1Password, the `claude.auth` handler needs
  a fallback. Coordinate with the user on where they'll store their API key.
- Token expiry: `ANTHROPIC_API_KEY` tokens from the Claude Console are
  typically long-lived. If a short-lived token expires, the wrapper's next
  invocation fetches a fresh one via the bridge. Mid-session expiry is not
  handled (unlikely in practice; Claude Code would get a 401 and surface it).
