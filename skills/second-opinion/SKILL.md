---
name: second-opinion
description: Get an independent answer or review from a different model family.
argument-hint: "[question, path, or git range — default: current changes]"
disable-model-invocation: true
---

Get a second opinion from a model family other than the one running this
session, then weigh it against your own view.

1. **Pick the target.** From Claude, ask Codex (fall back to OpenCode with a
   non-Anthropic model). From Codex, ask Claude Code. From OpenCode, ask
   whichever of the two is a different family from the current model. Check
   availability with `command -v codex claude opencode`. If none is usable
   (missing, unauthenticated, or blocked by the sandbox), say so and stop;
   the point is an independent opinion, so don't substitute your own.
2. **Frame the ask.** With arguments, use them as the question, or as the path
   or git range to review. Without arguments, review the current changes:
   staged if any, otherwise the working tree against `HEAD`.
3. **Dispatch** a read-only peer review following the `delegation` skill's
   peer-review recipe. Pass the question or range and any intent the
   conversation has established. Don't paste the diff into the command line;
   the reviewer can run `git diff` itself. In Claude Code, the
   `external-reviewer` subagent does this and keeps the raw output out of
   your context.
4. **Report.** Show the response under `Source: <CLI> (<model>)`. Then check
   its claims against the code and add a short note: where you agree, where
   you disagree and why, and which findings you verified.
