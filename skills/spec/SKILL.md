---
name: spec
description: Spec-driven workflow wrapper — how planning, implementation, and verification compose on this system. Load when starting any non-trivial feature or change (multi-file, needs design decisions, or the user asks for a plan/proposal/spec). Routes planning to OpenSpec (/opsx), execution to the delegation skill, and quality gates to the discipline skills.
---

# Spec-Driven Workflow

This skill is the glue: OpenSpec owns the *artifacts*, `delegation` owns the
*execution*, and the `sp-*` discipline skills own the *quality gates*. Use it
to pick the right tool at each stage instead of inventing a bespoke plan
format.

## When to spec

- **Spec it** — multi-file changes, anything needing design decisions, or when
  the user asks for a plan/proposal. Use the OpenSpec flow below.
- **Skip it** — trivial fixes (roughly: one file, <30 lines). Just implement,
  with `sp-verification-before-completion` before claiming done.
- **Just thinking?** `/opsx:explore` (openspec-explore skill) — thinking
  partner mode, no artifacts created until direction is clear.

## Where specs live (decide once per project)

1. **Committed** (default for projects where specs are living docs): the repo
   has an `openspec/` directory; changes and specs are committed like code.
2. **Local-only** (specs stay out of the repo): run `openspec init --tools none`
   in the repo, then add `openspec/` to `.git/info/exclude` (NOT `.gitignore` —
   the exclusion itself stays private). Full tooling, zero repo footprint.
3. Check before initializing: if `openspec/` already exists, respect the
   existing mode.

> openspec >= 1.5.0 adds *stores* (planning repos that live entirely outside
> code repos). When the installed version supports it, prefer a personal store
> over mode 2.

## The flow

1. **Explore** — `/opsx:explore` to align on the problem and approach.
2. **Propose** — `/opsx:propose` (openspec-propose skill) creates the change:
   `proposal.md` (why/what), `design.md` (how), spec deltas (SHALL requirements
   with Given/When/Then scenarios), `tasks.md` (implementation checklist).
   This replaces ad-hoc plan documents — there is no separate "write a plan"
   step.
3. **Apply** — `/opsx:apply` (openspec-apply-change skill) implements
   `tasks.md`. As the strong-tier orchestrator, do NOT implement task-by-task
   yourself: load `delegation` and dispatch tasks to `builder` workers
   (or follow `sp-subagent-driven-development`, pointing it at the change's
   `tasks.md` as the plan). Disciplines during apply:
   - `sp-test-driven-development` for each task with testable behavior
   - `sp-systematic-debugging` when something breaks
   - `sp-using-git-worktrees` if the work needs isolation
4. **Verify & close** — `sp-verification-before-completion` before declaring
   any task done (run the commands, read the output). Then `/opsx:archive`
   (openspec-archive-change) to archive the change and update main specs
   (`/opsx:sync` if spec deltas need syncing without archiving).

## Rules

- One change = one `openspec/changes/<name>/` directory. Don't batch unrelated
  work into one change.
- Artifacts are living documents: when implementation reveals the design was
  wrong, update the artifacts, then continue — don't let tasks.md drift from
  reality.
- `openspec validate <change>` before archiving.
- Specs in local-only mode are still real specs: same rigor, same format —
  they're just not shared.
