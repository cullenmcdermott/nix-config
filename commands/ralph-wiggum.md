---
description: Iterative review-fix-review loop alternating models until convergence
---

# Ralph Wiggum - Iterative Review & Fix Loop

You are running an iterative improvement loop that alternates between different reviewers and fixing code until quality converges.

## Process

### Round 1 — Claude Review
1. Spawn `reviewer-architect` sub-agent on the current code changes
2. Wait for structured feedback with issues and severity scores (0-10)
3. Apply the fixes directly in the main conversation
4. Stage only the files you modified: `git add <specific-files>`

### Round 2 — External Review
1. Spawn `external-reviewer` sub-agent on the updated code (including fixes from round 1)
2. Wait for feedback from the non-Claude model
3. Apply fixes in the main conversation
4. Stage the fixes

### Subsequent Rounds
Continue alternating between `reviewer-architect` and `external-reviewer` (or `reviewer-tester`, `reviewer-perf` for variety).

## Convergence Criteria

Stop the loop when ANY of these conditions are met:
1. **Low severity**: All remaining issues have severity <= 2 (out of 10)
2. **Plateau**: Less than 20% reduction in issues between rounds
3. **Max iterations**: 4 rounds completed
4. **No new issues**: No unique issues found in the latest round

## Output

After convergence, report:
- **Rounds completed**: N
- **Issues found and fixed**: summary per round
- **Remaining issues**: any low-severity items left unfixed (by choice)
- **Convergence reason**: which criteria triggered the stop
- **Models used**: which reviewer was used in each round

## Important

- Always show the user what changes are being made between rounds
- If a fix introduces new issues, note the regression
- If the external CLI is unavailable, alternate between different Claude sub-agents instead (architect → tester → perf)
