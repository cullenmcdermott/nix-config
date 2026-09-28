---
name: handover
description: Write a handover document so a fresh session can pick up this work.
argument-hint: "[what the next session will focus on]"
disable-model-invocation: true
---

Write a handover document that lets a fresh agent, with none of this
conversation, continue the work without the user re-explaining anything.

Save it outside the workspace, in the OS temp directory:
`${TMPDIR:-/tmp}/handover-<yyyy-mm-dd>-<short-slug>.md`.

If arguments were given, they describe what the next session will focus on;
tailor the document to that.

Cover:
- **Goal** and the current state of the work: done, in progress (with the
  exact point reached), and what's next, as concrete first actions.
- **What we learned**: findings, decisions and their reasons, and approaches
  that failed and why, so they aren't retried.
- **Open questions and blockers.**
- **Where things are**: repo, branch, and uncommitted changes (`git status`).
  Point to existing artifacts (specs, plans, ADRs, issues, commits, diffs) by
  path or URL instead of copying their content.
- **Suggested skills** the next session should load.

Redact secrets, tokens, and personal data.

Finish by printing the file path and a one-line continuation prompt for the
user to paste, e.g. `Read <path> and continue from "Next steps".`

<!-- Adapted from mattpocock/skills `handoff` (MIT). -->
