---
description: Quick dispatch to an external LLM CLI for a non-Claude perspective
---

# Second Opinion

You are dispatching a question or code review to an external (non-Claude) LLM CLI to get a different perspective.

## Step 1: Discover Available CLIs

```bash
uv run ~/.claude/skills/llm-orchestrator/scripts/discover_llm_clis.py
```

## Step 2: Dispatch

Use the best available external CLI. Priority order:

If the user provided a specific question, write it to a temp file and pipe it. If no question was provided, pipe the current staged diff with a review prompt. **Never embed `$(git diff)` or user input directly in command arguments** — always pipe via stdin to avoid shell injection and ARG_MAX limits.

1. **`cursor-agent`** (Cursor CLI):
   ```bash
   git diff --cached | cursor-agent -p "Review the following code change piped via stdin for issues:" --output-format json
   ```

2. **`llm`**:
   ```bash
   git diff --cached | llm "Review this code change for issues:"
   ```

3. **`gemini`**:
   ```bash
   git diff --cached | gemini "Review this code change:"
   ```

## Step 3: Present Result

Show the external model's response clearly:

**Source**: [CLI name] ([model name if known])

> [external model's response]

If you have a different perspective from the external model, add your own brief commentary noting agreements and disagreements.

## If No External CLI Available

Tell the user that no external LLM CLI is currently installed. Suggest installing one:
- `cursor-agent` (Cursor CLI) — already in nix config as `pkgs.cursor-cli`
- `llm` (Simon Willison's tool) — `nix run nixpkgs#llm`
