---
name: delegation
description: Tiered-model orchestration — a strong model plans, decomposes, and reviews while weak-model workers implement. Load before dispatching implementation work when acting as the orchestrator (see the "Orchestrate, Don't Implement" policy in global context).
---

# Delegation

You are the tech lead. Workers own keystrokes; you own correctness. This skill covers the dispatch mechanics and the review loop. The concrete model names for "strong" and "weak" tiers are defined in your global context (CLAUDE.md / AGENTS.md), not here.

## 1. Decompose

Break the work into tasks that are independently implementable and verifiable. Each task must fit in a worker's context without your conversation history — workers see only the prompt you give them.

For multi-task work, the plan artifact comes from the spec workflow — an
OpenSpec change's `tasks.md` (see the `spec` skill), not a bespoke plan doc.
Then use the existing skills rather than reinventing them:
- `sp-subagent-driven-development` — executing the tasks one-by-one via
  subagents (point it at the change's `tasks.md` as the plan)
- `sp-dispatching-parallel-agents` — when 2+ tasks are independent

## 2. Dispatch

### In Claude Code
- **Implementation** → the `builder` agent (pinned to the weak model). One task per dispatch.
- **Codebase exploration/search** → the `Explore` agent.
- Independent tasks: dispatch in parallel (single message, multiple Agent calls). Tasks touching the same files: sequential, or use worktree isolation.
- In Workflow scripts, pass `effort: 'low'` for mechanical stages and reserve high effort for verify/judge stages.

### In Codex
- Dispatch via non-interactive exec with the weak model, one task per invocation:
  ```
  codex exec -m <weak-model> -c model_reasoning_effort=low "<task prompt>"
  ```
  Use `model_reasoning_effort=low` for mechanical work, `medium` for normal implementation.

## 3. Write the task prompt

Workers have none of your context. Every dispatch includes:

1. **Goal** — one sentence, what done looks like
2. **Files** — exact paths to read and to change
3. **Approach** — the design decision you already made (workers execute, they don't choose)
4. **Constraints** — style, APIs to use/avoid, what NOT to touch
5. **Acceptance** — the commands that must pass, expected behavior

## 4. Review loop

For every worker result, before accepting:

1. Read the actual diff (`git diff`) — not the worker's summary of it.
2. Check scope: nothing changed beyond the task.
3. Run the verification yourself (tests, build, lint). Worker claims are not evidence — see `sp-verification-before-completion`.
4. Accept, or re-dispatch with a corrected prompt that names the specific defect.

**Escalation:** if a worker fails the same task twice, implement it yourself. Don't loop a third time.

## When NOT to delegate

- Trivial changes (roughly: one file, <30 lines) — dispatch overhead exceeds the task.
- Architectural decisions, final verification, git commits, anything destructive — always yours.
- You are already the weak tier (check your model identity) — just implement.
