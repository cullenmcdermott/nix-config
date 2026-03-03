---
description: Multi-persona code review — scales reviewer count based on change complexity
---

# Multi-Persona Code Review

You are orchestrating a multi-perspective code review using specialized sub-agents.

## Step 1: Assess Complexity

Run the complexity assessment script on the current changes:

```bash
uv run ~/.claude/skills/llm-orchestrator/scripts/assess_complexity.py --diff-args "HEAD~1"
```

If the user specified a diff range (e.g., "review changes since main"), use that instead:
```bash
uv run ~/.claude/skills/llm-orchestrator/scripts/assess_complexity.py --diff-args "main"
```

Parse the JSON output to determine which reviewers to spawn.

## Step 2: Get the Diff

Capture the diff that will be reviewed:
```bash
git diff HEAD~1
```

(Or the user-specified range)

## Step 3: Spawn Reviewer Sub-Agents

Based on the complexity level, spawn the recommended reviewer sub-agents **in parallel** using the Agent tool with `run_in_background: true`.

Each agent should receive:
- The diff to review
- A clear instruction to review from their specific perspective
- The file list for context

Use the `recommended_reviewers` array from the JSON output to determine which agents to spawn. Do not hardcode the mapping — the script is the single source of truth.

## Step 4: Synthesize Results

Once all agents complete, synthesize their findings into a single report:

### Priority-Ordered Findings

Group findings by severity (critical → high → medium → low → nit), deduplicating across reviewers.

For each finding:
- **Severity** | **Category** | **Reviewer**
- **Location**: file:line
- **Issue**: description
- **Suggestion**: fix

### Summary

- Total findings by severity
- Top 3 most important issues to address
- Overall assessment: approve / request changes / needs discussion
