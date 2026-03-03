---
description: Architecture Decision Record generator — evaluates options from multiple angles
---

# ADR Generator

Generate a structured Architecture Decision Record by evaluating the question from multiple engineering perspectives.

## Input

The user provides an architecture question or decision to evaluate. For example:
- "Should we use PostgreSQL or MongoDB for the user service?"
- "How should we handle authentication — JWT vs sessions?"
- "Should we adopt a monorepo or keep separate repos?"

## Step 1: Fan Out to Perspectives

Spawn agents **in parallel** to evaluate the decision from different angles:

### Agent 1: reviewer-architect
Prompt: "Evaluate this architecture decision from a system design perspective. Consider scalability, maintainability, and simplicity: [question]"

### Agent 2: reviewer-perf
Prompt: "Evaluate this architecture decision from a performance perspective. Consider throughput, latency, and resource usage: [question]"

### Agent 3: reviewer-security
Prompt: "Evaluate this architecture decision from a security perspective. Consider attack surface, data protection, and compliance: [question]"

## Step 2: Synthesize ADR

Combine the perspectives into a structured ADR:

```markdown
# ADR: [Decision Title]

## Status
Proposed

## Context
[What is the problem or question? What forces are at play?]

## Decision Drivers
- [driver from architecture perspective]
- [driver from performance perspective]
- [driver from security perspective]
- [operational considerations]

## Considered Options

### Option 1: [Name]
- **Architecture**: [pros/cons]
- **Performance**: [pros/cons]
- **Security**: [pros/cons]

### Option 2: [Name]
- **Architecture**: [pros/cons]
- **Performance**: [pros/cons]
- **Security**: [pros/cons]

### Option 3: [Name] (if applicable)
- **Architecture**: [pros/cons]
- **Performance**: [pros/cons]
- **Security**: [pros/cons]

## Recommendation
[Which option and why, considering all perspectives]

## Consequences

### Positive
- [benefit 1]

### Negative
- [tradeoff 1]

### Risks
- [risk 1 and mitigation]
```

## Step 3: Present

Print the full ADR. Ask the user if they want to save it to a file (e.g., `docs/adr/NNN-decision-title.md`).
