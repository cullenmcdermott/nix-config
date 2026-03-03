---
description: Multi-model test generation — independent test cases merged and deduped
---

# Multi-Model Test Generator

Generate comprehensive test cases by getting independent suggestions from multiple perspectives, then merging and deduplicating.

## Input

The user provides source file(s) to generate tests for.

## Step 1: Read the Source

Read the target file(s) to understand:
- The programming language and test framework in use
- Existing test patterns in the project
- The functions/classes that need testing

## Step 2: Fan Out Test Generation

Spawn agents **in parallel**:

### Agent 1: reviewer-tester
Prompt: "Generate comprehensive test cases for this code. Focus on happy paths, edge cases, and error handling. Use the existing test framework conventions. [source code]"

### Agent 2: reviewer-architect
Prompt: "Generate integration-level test cases for this code. Focus on how components interact, API contracts, and boundary conditions. [source code]"

### Agent 3: reviewer-security
Prompt: "Generate security-focused test cases for this code. Test for injection, auth bypass, data leakage, and input validation. [source code]"

## Step 3: Merge and Deduplicate

1. Collect all test cases from the agents
2. Group by test intent (what behavior is being tested), not exact code
3. Deduplicate tests that cover the same scenario
4. Keep the best implementation of each unique test case
5. Ensure no conflicts between test cases

## Step 4: Present Unified Test Suite

Present the merged test suite organized by category:

```
### Happy Path Tests
- [test descriptions]

### Edge Case Tests
- [test descriptions]

### Error Handling Tests
- [test descriptions]

### Security Tests
- [test descriptions]

### Integration Tests
- [test descriptions]
```

Show the full test code, ready to be written to a file. Ask the user where to save it.
