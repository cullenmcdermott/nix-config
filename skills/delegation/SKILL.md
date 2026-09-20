---
name: delegation
description: Delegate bounded implementation, investigation, or peer review work from Codex, Claude Code, or OpenCode to any of those harnesses using their native CLIs. Load before dispatching another agent; preserve the parent's task scope and permission boundaries.
---

# Delegation

Any of the three harnesses can request work from any other, including itself.
Use the native CLI through the parent's shell tool; no bridge server is needed.
Follow the model tiers in the current AGENTS.md / CLAUDE.md when specified.
The parent owns design, scope, integration, and final verification. A delegated
worker implements its assigned task directly and does not delegate again unless
the parent explicitly authorizes it. Handle trivial work locally.

## Prepare the handoff

- Give one bounded task per invocation: goal, repository root, files to read and
  change, design decisions, constraints, and acceptance commands.
- Include relevant conversation decisions and permission restrictions explicitly.
  New CLI sessions do not inherit the conversation, in-memory tools, approvals,
  or sandbox configuration. They load their own configured skills, tools, and
  project instructions; verify required capabilities are available.
- Launch in the intended repository or isolated worktree. Record `git status`
  and the existing diff so another agent's changes are distinguishable from the
  user's work. Parallel writers need disjoint files or separate worktrees.
- For a peer review, specify the base commit or exact diff and request findings
  with file/line evidence. Explicitly prohibit edits, commits, and delegation.

## Dispatch with native CLIs

Check `codex exec --help`, `claude --help`, or `opencode run --help` if flags
or installed versions differ. Use configured models unless task instructions
specify one. Codex accepts `-m MODEL` and
`-c model_reasoning_effort=medium` (low for mechanical work); Claude accepts
`--model MODEL`; OpenCode accepts `--model PROVIDER/MODEL`.

Use a quoted heredoc or a file written by the filesystem tool for task text.
Never interpolate an untrusted task into shell code or use `eval`.
For example, from the intended repository root:

```sh
agent_task_dir=$(mktemp -d)
cat > "$agent_task_dir/task.md" <<'TASK'
You are an implementation worker. Do not delegate further.
Goal: implement the parent-specified change described below.
Read the repository instructions first. Preserve existing user changes.
Allowed files: [exact paths]. Approach: [design decision].
Constraints: [scope, network/write limits, applicable parent restrictions].
Acceptance: [commands and expected behavior].
If permissions block work, stop and report the blocked action to the parent.
Do not commit or publish. Report changed files and verification results.
TASK
```

Replace the bracketed handoff details, then choose **one** invocation:

```sh
# Codex: prompt from stdin; optional model override follows local tier policy.
codex exec -C "$PWD" - < "$agent_task_dir/task.md"

# Claude Code: print mode reads the prompt from stdin.
# Requests requiring an unavailable interactive approver are denied.
claude --print --permission-prompts none < "$agent_task_dir/task.md"

# OpenCode: attach the prompt file, keeping shell arguments literal.
opencode run --dir "$PWD" --file "$agent_task_dir/task.md" -- 'Complete the task in the attached task.md.'
```

For an independent peer review, write this kind of task to a separate file and
use the same dispatch commands (Codex additionally supports `-s read-only`):

```text
You are a peer reviewer. Do not edit files, commit, or delegate.
Review [exact paths/diff against BASE] for correctness and regressions.
Intended behavior: [requirements]. Constraints: [parent restrictions].
Read the actual diff and relevant callers. Return actionable findings with
file/line evidence, severity, and suggested corrections; say if none are found.
Report any checks you could not perform. Do not request expanded permissions.
```

Keep output and exit status, and remove the temporary task directory when done.
Do not resume an unrelated session or attach to a different server just to
reuse its credentials or approvals.

## Permissions and escalation

Permission settings belong to each harness; similar defaults are not equivalent
enforcement. The child must stay within the parent's authorized scope and
restrictions. Preserve the enclosing sandbox and apply supported restrictions
when necessary; a prompt alone is not a sandbox. If required boundaries cannot
be enforced, keep that work in the parent or use an appropriately isolated child.

Do not add bypass flags, auto-allow overrides, broader write roots, or disable
nesting guards to get a child running. Do not retry a denied action through
another harness. A blocked child reports the action and reason; the parent
handles any needed escalation through its normal approval mechanism. Approval
for a child launch does not approve unrelated actions inside the child. If a
CLI is unavailable or unauthenticated, report that limitation; do not install
packages or change credentials as part of delegation.

## Accept the result

Read the actual diff against the pre-dispatch state, check scope, and run the
relevant verification yourself. A worker's success message is not evidence.
Treat peer review findings as claims to check. Send a focused correction when
needed; after two failed attempts at the same task, finish locally or report
the concrete blocker. The parent retains commits, publishing, and destructive
operations unless the user explicitly assigned them to the child.
