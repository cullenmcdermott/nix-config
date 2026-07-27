---
name: converge
description: Harden an already-decided plan into a self-terminating autonomous-goal spec — a checklist with machine-checkable exit criteria, a non-gameable Definition-of-Done "convergence gate", and a gate-first /goal (or /loop) driver prompt that memoryless, multi-session drivers converge on and HALT. Use when the user wants to hand an autonomous driver a "true definition of done" — e.g. "draft a goal I can run with /goal until it's done", "define exit criteria and stop when complete", "make it converge". NOT for deciding WHAT the work is (use /opsx or the spec skill for interactive, human-in-the-loop planning); this hardens a plan you already have into something a driver can finish on its own.
---

# Converge — author a self-terminating autonomous-goal spec

The niche: you have a decided plan (a pile of remaining work) and you want to
hand it to an **autonomous driver** (`/goal`, `/loop`, a cron routine) that runs
the SAME prompt across many **memoryless** sessions until the work is done — and
then stops. The hard part isn't the plan; it's writing a **Definition of Done the
driver can't game, can't loop on, and recognizes immediately once met.** This
skill produces that artifact.

## When to use / when NOT

- **Use it** when the deliverables are already known and the ask is "drive this
  to done autonomously" / "define exit criteria" / "converge and halt."
- **Don't use it** to figure out *what* to build — that's interactive planning:
  route to `/opsx` (OpenSpec) or the `spec` skill first, then converge the result.
- **Don't use it** for a one-off task a single session finishes — just do it and
  run `sp-verification-before-completion`.

## The four steps

1. **Decompose** the remaining work into a checklist of items small enough that
   one session can finish one. Give each a `*(blockers: …)*` list (other item
   IDs) so ordering is deterministic. Put quick, dependency-free closers first.
2. **Attach exit criteria** to every item: **commands**, not prose. "Passes" must
   be observable (`go test ./x/`, a golden file exists, an `rg` assertion). If a
   human would have to eyeball it, it's not an exit criterion yet — find the
   command that proves it.
3. **Write the Convergence Gate** — the Definition of Done: every box ticked AND a
   short list of commands all green. This is the single check that says "done."
   Run it through `references/convergence-footguns.md` — that checklist is why the
   gate won't lie or loop.
4. **Emit the driver prompt** — the gate-first `/goal` prompt (template below).
   Gate-first ordering is what makes a finished goal converge *immediately*: every
   session checks done before touching anything.

Persist all of this in ONE tracked file (e.g. `docs/<goal>-goals.md` or a
`TODO.md` workstream). The file — not conversation memory — is the shared state
across sessions. State must be **monotonic and tick-only**: a rule may never
untick a box, so a crashed/half-done session just leaves the box unticked and the
next session retries. That is what keeps memoryless multi-session drivers
convergent.

## Before you emit: run the footgun review

Read `references/convergence-footguns.md` and fix every match. The common killers:
vacuous gate commands (`go test -run X` exits 0 when nothing matches), `rg`
exit-2 / `!`-negation masking errors as passes, comment-satisfiable greps, and the
two undefined states that loop forever ("all ticked but a gate regressed" and "no
eligible item"). A gate that hasn't been through this checklist will either never
halt or halt early.

## Goal-file skeleton

```markdown
# Goal: <one line>
Status: active   # a decided, driver-ready spec (the session that emits GOAL COMPLETE may flip to `done`)

## Definition of Done (Convergence Gate)
Complete when EVERY box below is ticked AND all pass (from repo root):
    <command 1>   # exits 0
    <command 2>   # ... (each with a comment naming what a pass means)

## Checklist
- [ ] **T1 — <deliverable>.** *(blockers: —)*
  - Exit: <command(s) that must pass>
- [ ] **T2 — <deliverable>.** *(blockers: T1)*
  - Exit: <command(s)>
...

## Rules for the driver
- <no-internal-imports / don't-break-X / TDD / branch-don't-commit / sandbox caveats>
- Eligibility is ONLY the *(blockers: …)* tick state; a blocker NOTE never makes
  an item ineligible. Never untick a box. One /goal session at a time — a dirty
  tree at start is the prior session's partial work on the top eligible item;
  continue it, don't discard or restart elsewhere.

## Session Log (append one line per session; newest last)
- (empty)
```

## The `/goal` driver prompt (emit this, tuned to the file path)

> Drive the goal in `<path>`. That file is the single source of truth for
> remaining work and the Definition of Done.
>
> STEP 1 — FIRST, every session, run the **Convergence Gate** commands in that
> file. If they ALL pass AND every Checklist box is ticked, output exactly
> `GOAL COMPLETE — <slug>` and STOP. Do nothing else.
>
> STEP 2 — Otherwise pick the TOP unchecked item whose blockers are all ticked.
> Implement it FULLY — production behavior, no placeholders/TODOs/empty stubs —
> test-first. Match the repo's conventions. Edge cases: (a) if every box is ticked
> but a Gate command FAILS, or a ticked item's Exit Criteria regressed, fixing
> that regression IS this session's task — never untick a box, just log the fix;
> (b) if NO unchecked item is eligible (all remaining blockers unticked), output
> exactly `GOAL BLOCKED — <reason>` and STOP; (c) if the Session Log shows 3+
> consecutive sessions that attempted the SAME item without ticking it, output
> `GOAL BLOCKED — <item>: <reason>` and STOP.
>
> STEP 3 — Verify against that item's **Exit Criteria** (run its commands; they
> must pass). Only then tick its box and append a one-line Session Log entry.
>
> STEP 4 — Re-run the Convergence Gate. If green and all ticked, output
> `GOAL COMPLETE — <slug>` and STOP; otherwise end the session.
>
> Guardrails: no scope-creep beyond the checklist; don't commit/push unless asked
> (branch off the default branch); honor the file's Rules and the repo's sandbox
> caveats. A dirty tree at start is the prior session's partial work on the top
> eligible item — continue it, don't discard or restart elsewhere. Never tick a
> box whose Exit Criteria you did not run and see pass.

## Output

Deliver two things: the goal file (written to the repo) and the tuned `/goal`
prompt (in chat, ready to paste into the driver). Do not commit unless asked.
