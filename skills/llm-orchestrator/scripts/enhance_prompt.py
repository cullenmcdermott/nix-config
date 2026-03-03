#!/usr/bin/env python3
"""Generate structured prompts for different LLM analysis tasks.

Usage:
    uv run scripts/enhance_prompt.py review
    uv run scripts/enhance_prompt.py security --context "Focus on SQL injection"
    uv run scripts/enhance_prompt.py commit-msg
"""

import argparse
import json
import sys

TEMPLATES = {
    "review": {
        "system": "You are an expert code reviewer. Provide actionable, specific feedback.",
        "prompt": """Review the following code changes. For each issue found, provide:

1. **Location**: File and line number
2. **Severity**: critical / high / medium / low / nit
3. **Category**: bug, design, performance, security, style, testing
4. **Issue**: What's wrong
5. **Suggestion**: How to fix it

Focus on:
- Correctness and edge cases
- API design and abstractions
- Error handling
- Naming and clarity

Output as a structured list. Start with the most critical issues.

{context}""",
    },
    "security": {
        "system": "You are a security engineer performing a code audit. Focus on OWASP Top 10 and common vulnerability patterns.",
        "prompt": """Perform a security audit on the following code changes. Check for:

1. **Injection** (SQL, command, LDAP, XSS)
2. **Authentication/Authorization** flaws
3. **Sensitive data exposure** (secrets, PII, tokens in logs)
4. **Security misconfiguration**
5. **Insecure deserialization**
6. **Known vulnerable components**
7. **Insufficient logging/monitoring**
8. **Cryptographic issues** (weak algorithms, hardcoded keys)

For each finding:
- **Severity**: critical / high / medium / low
- **CWE**: Applicable CWE number if known
- **Location**: File and line
- **Issue**: Description of the vulnerability
- **Impact**: What an attacker could do
- **Remediation**: Specific fix

{context}""",
    },
    "test-gen": {
        "system": "You are a test engineer. Generate comprehensive, practical test cases.",
        "prompt": """Generate test cases for the following code. Include:

1. **Happy path** tests for normal operation
2. **Edge cases** (empty inputs, boundaries, nulls)
3. **Error cases** (invalid inputs, failures, exceptions)
4. **Integration points** (mocks/stubs for external dependencies)

For each test:
- Clear test name describing the scenario
- Setup/arrange section
- Action/act section
- Assertion/assert section

Use the testing framework conventions already present in the codebase.

{context}""",
    },
    "explain": {
        "system": "You are a senior engineer explaining code changes to the team.",
        "prompt": """Explain the following code changes from multiple angles:

1. **What changed**: Summary of the modifications
2. **Why it matters**: Business/technical impact
3. **How it works**: Technical walkthrough of the key changes
4. **Architecture impact**: How this affects the broader system
5. **Risk areas**: What could go wrong, what to watch in production

Keep explanations clear and concise. Use concrete examples from the diff.

{context}""",
    },
    "commit-msg": {
        "system": "You write clear, conventional commit messages following the project's existing style.",
        "prompt": """Generate a commit message for the following changes.

Rules:
- First line: imperative mood, under 72 characters, no period
- Match the style of recent commits in the repository
- Be specific about what changed, not why (the diff shows what)
- If the change is simple, one line is sufficient
- For complex changes, add a blank line then a brief body

Also generate an extended description suitable for a merge request body (separate from the commit message). The MR description should explain the WHY and include any testing notes.

Output format:
COMMIT_MSG: <the commit message>
MR_DESCRIPTION: <the extended description>

{context}""",
    },
    "adr": {
        "system": "You are a software architect documenting decisions using the ADR format.",
        "prompt": """Evaluate the following architecture question and generate a structured Architecture Decision Record (ADR).

Format:
# ADR-NNN: <Title>

## Status
Proposed

## Context
<What is the issue we're facing? What forces are at play?>

## Decision Drivers
- <driver 1>
- <driver 2>

## Considered Options
1. <Option A> - <brief description>
2. <Option B> - <brief description>
3. <Option C> - <brief description>

## Decision
<Which option was chosen and why>

## Consequences
### Positive
- <benefit 1>

### Negative
- <tradeoff 1>

### Risks
- <risk 1>

{context}""",
    },
}


def main():
    parser = argparse.ArgumentParser(description="Generate structured LLM prompts")
    parser.add_argument(
        "task_type",
        choices=list(TEMPLATES.keys()),
        help="Type of analysis task",
    )
    parser.add_argument(
        "--context",
        default="",
        help="Additional context to include in the prompt",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="output_json",
        help="Output as JSON with system and prompt fields",
    )
    args = parser.parse_args()

    template = TEMPLATES[args.task_type]
    context_line = f"\nAdditional context: {args.context}" if args.context else ""
    prompt = template["prompt"].replace("{context}", context_line).strip()

    if args.output_json:
        json.dump(
            {"system": template["system"], "prompt": prompt},
            sys.stdout,
            indent=2,
        )
        print()
    else:
        print(prompt)


if __name__ == "__main__":
    main()
