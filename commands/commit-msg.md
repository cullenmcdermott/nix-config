---
description: Generate a commit message with optional MR description using multi-model consensus
---

# Commit Message Generator

Generate a concise commit message and optional merge request description.

## Step 1: Gather Context

Run these in parallel:

```bash
git diff --cached
```

```bash
git log --oneline -10
```

If nothing is staged, use `git diff HEAD~1` instead.

## Step 2: Generate Commit Message

Analyze the diff and recent commit history to match the project's style.

Rules:
- **First line**: imperative mood, under 72 characters, no period
- Match the tone and format of recent commits
- Be specific about what changed
- One line is sufficient for simple changes

## Step 3: Generate MR Description (if changes are non-trivial)

For changes touching more than 2-3 files or with significant logic:

```markdown
## Summary
- [key change 1]
- [key change 2]

## Details
[Explanation of why these changes were made]

## Testing
[How this was tested or should be tested]
```

## Step 4: Present Results

```
Commit message:
  <the commit message>
```

If an MR description was generated:
```
MR Description:
  <the description>
```

Ask the user if they want to:
1. Use the commit message as-is
2. Edit it
3. Also get an external model's suggestion (if available)
