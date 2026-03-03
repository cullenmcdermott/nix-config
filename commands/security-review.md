---
description: Security-focused multi-agent audit with different OWASP focus areas
---

# Security-Focused Code Audit

You are orchestrating a security audit using multiple specialized perspectives.

## Step 1: Get the Changes

```bash
git diff HEAD~1
```

If the user specified a range, use that instead.

## Step 2: Spawn Security Reviewers

Launch the following agents **in parallel** using the Agent tool with `run_in_background: true`:

### Agent 1: reviewer-security
Full OWASP Top 10 audit of the changes. This is the primary security reviewer.

### Agent 2: reviewer-architect
Focus specifically on security architecture: auth boundaries, trust zones, data flow between components.

### Agent 3: external-reviewer
Get a non-Claude perspective on security issues. External models sometimes catch different patterns.

## Step 3: Synthesize Security Report

Combine findings into a structured security report:

### Critical / High Findings
Must be addressed before merge. Include CWE references where applicable.

### Medium / Low Findings
Should be addressed but not blocking.

### Security Posture Assessment
- Are authentication/authorization boundaries correct?
- Is sensitive data handled appropriately?
- Are there any new attack surface areas introduced?
- Compliance considerations (if applicable)

### Recommendations
Prioritized list of security improvements.
