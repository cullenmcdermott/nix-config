---
description: Multi-angle diff explanation covering architecture, security, and performance
---

# Multi-Angle Diff Explanation

You are explaining code changes from multiple engineering perspectives.

## Step 1: Get the Diff

```bash
git diff HEAD~1
```

Or use the user-specified range.

## Step 2: Spawn Explanation Agents

Launch these agents **in parallel** using the Agent tool with `run_in_background: true`:

### Agent 1: reviewer-architect
Prompt: "Explain these changes from an architectural perspective. What design decisions were made? How does this affect the system's structure?"

### Agent 2: reviewer-security
Prompt: "Explain any security implications of these changes. What attack surface changed? Are there new trust boundaries?"

### Agent 3: reviewer-perf
Prompt: "Explain the performance implications of these changes. Are there any algorithmic or I/O concerns?"

## Step 3: Synthesize Explanation

Combine the perspectives into a clear, unified explanation:

### What Changed
Brief summary of the modifications.

### Architecture Perspective
How this fits into the system design.

### Security Perspective
Any security implications (or "no security impact" if none).

### Performance Perspective
Any performance considerations (or "no performance impact" if none).

### Key Takeaways
The 2-3 most important things a reviewer should know about this change.
