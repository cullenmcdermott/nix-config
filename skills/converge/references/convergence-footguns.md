# Convergence footguns — the pre-flight review before emitting a goal spec

A goal spec fails in one of two ways: it **never halts** (a session loops or
re-opens finished work) or it **halts early** (the gate reports done when it
isn't). Both come from a handful of specific mistakes. Walk this list against
your Convergence Gate and Checklist before emitting; fix every match.

## Gate commands that lie (halt-early)

1. **Vacuous test selectors.** `go test ./x/ -run TestFoo` exits 0 even when NO
   test matches ("no tests to run"); `jest -t` skips all and exits 0 too.
   (`pytest -k` exits 5 on no match, which is safer — but a renamed test still
   silently weakens the gate.) Any gate that "runs a named test" also needs a
   separate assertion that the test *exists*: `rg -q 'func TestFoo\(' path/` (or
   the language's equivalent). Assert existence, THEN run.

2. **`rg` exit-2 masked as a pass.** `rg` exits 0 on match, 1 on no-match, **2 on
   error** (bad path, missing dir, bad regex). `! rg PATTERN dir/` turns the error
   (2) into a "pass" just like a clean no-match (1). For a "must find NOTHING"
   gate, assert the clean code explicitly: `rg PATTERN dir/; test $? -eq 1`.
   Never use `!` in front of the tool whose absence you're asserting. Run
   `test $? -eq 1` as its OWN command line — under `set -e`, or inside an `&&`
   chain, the `rg` exit-1 aborts before `test` ever runs.

3. **Comment-satisfiable greps.** `rg -q 'tui/transcript' file` matches
   `// TODO: use tui/transcript`. Anchor "the code really uses X" gates to
   something a comment can't fake — the quoted import path
   (`rg -q '"…/tui/transcript'`), a symbol definition, or a passing test.

4. **`grep`/`find` on a not-yet-created path** exit non-zero or print nothing;
   an agent can read "no matches" as "no violations → pass." Gate the *existence*
   of the artifact separately from its *contents*.

5. **Cached / stale success.** If the gate builds or tests, make sure it can't
   pass on cached output from a prior state. Prefer a fresh check, or include a
   drift/gen check (e.g. generated files match source) in the gate.

## Undefined states that loop forever (never-halt)

6. **"All boxes ticked but a gate command fails."** A later item regressed an
   earlier one; there is no unchecked item for STEP-2 to pick, and no rule says
   what to do → the driver stalls or thrashes. Add an explicit rule: *fixing the
   regression is this session's task; never untick a box.*

7. **Missing `GOAL BLOCKED` sentinel.** Two states leave STEP 2 with nothing to
   pick and no way out → infinite non-halt. (a) **No eligible item** — every
   unchecked item has an unticked blocker. In a DAG this is UNREACHABLE (some item
   always has all blockers ticked); it only happens with a blocker *cycle* or a
   blocker ID that names no real item. (b) **A stuck item** — an eligible item
   that keeps failing (external dependency, needs a human): each session picks the
   same top item, fails, leaves it unticked, forever — the Session Log grows but
   nothing reads it. Give the driver BOTH escapes: emit `GOAL BLOCKED — <reason>`
   and STOP when no item is eligible, OR when the Session Log shows 3+ consecutive
   sessions that attempted the same item without ticking it.

8. **`*(blockers: …)*` gaps.** A "final gate / polish" item almost always depends
   on everything; if you forget its blockers it becomes eligible early and its
   exit greps run against dirs that don't exist yet (see #4) → ticked early. Every
   integration/final item lists all its blockers. And every blocker ID must name a
   REAL checklist item, with the blocker graph ACYCLIC — a cycle or a dangling ID
   strands items with no eligible pick (the #7 blocked state).

9. **Blocker NOTES vs blocker STATE.** If the driver may write a "blocked because
   X" note under an item, say clearly that eligibility is decided ONLY by the
   `*(blockers:)*` tick state — a prose note must NOT silently make an item
   ineligible, or a stale note wedges a memoryless session. Tell it to re-check
   and delete notes each session.

## State-model hazards (multi-session, memoryless)

10. **Non-monotonic state.** Any rule that unticks a box (or rewrites the
    checklist) breaks convergence: a crash mid-edit or a disagreeing session can
    oscillate. State must be **tick-only**. A half-done item stays unticked and is
    simply retried — that's the whole reason it converges.

11. **Concurrency.** Two drivers on the same file race on ticking/editing. State-
    in-file survives a *crash* (convergent) but not *concurrent writers*. Add a
    rule: at most one session at a time; a dirty tree holds the prior session's
    partial work on the top eligible item — finish THAT, don't restart elsewhere.

12. **Sentinel ambiguity.** The completion output must be an exact, greppable
    string (`GOAL COMPLETE — <slug>`) so the human/driver can detect halt
    unambiguously. Don't let it be a paraphrase.

## Ordering

13. **Gate-first is mandatory.** The driver must run the Convergence Gate as
    STEP 1, before touching anything. That single choice is what makes a finished
    goal converge *immediately* — every session recognizes done and halts instead
    of hunting for more work. A gate checked only at the end lets a completed goal
    keep doing (and undoing) work.

## The passing shape

A sound spec has: tick-only monotonic state in one file; deterministic
top-eligible ordering via `*(blockers:)*`; per-item exit criteria that are
existence-checked, error-safe commands; a gate-first driver; explicit
`GOAL COMPLETE` / `GOAL BLOCKED` sentinels; and rules covering regression-repair,
note-vs-state eligibility, and single-session concurrency. If all of those hold,
it converges cleanly and halts the instant the file + commands agree it's done.
