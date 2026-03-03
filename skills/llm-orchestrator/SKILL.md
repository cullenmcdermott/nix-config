---
name: llm-orchestrator
description: Multi-LLM orchestration utilities for discovering available CLI tools, assessing change complexity, and building structured prompts. Used by reviewer sub-agents and multi-model commands.
---

# LLM Orchestrator

## Overview

This skill provides shared infrastructure for multi-LLM orchestration workflows. It enables discovering which LLM CLI tools are installed, assessing the complexity of code changes to determine reviewer allocation, and generating structured prompts for different review/analysis tasks.

## Available Scripts

### `scripts/discover_llm_clis.py`
Detect installed and authenticated LLM CLI tools. Returns JSON with availability status for each supported CLI.

**Usage:** `uv run scripts/discover_llm_clis.py`

**Output format:**
```json
{
  "available": ["claude"],
  "unavailable": ["cursor-agent", "llm", "gemini", "aider"],
  "details": {
    "claude": {"installed": true, "path": "/usr/bin/claude", "version": "2.1.36"}
  }
}
```

### `scripts/assess_complexity.py`
Analyze a git diff to determine change complexity and recommend reviewer allocation.

**Usage:** `uv run scripts/assess_complexity.py [--diff-args "HEAD~1"]`

Defaults to staged changes if no diff args provided.

**Complexity levels:**
| Level | Criteria | Recommended Reviewers |
|-------|----------|-----------------------|
| small | <50 lines, 1-2 files | architect + stylist (2) |
| medium | 50-200 lines, 3-5 files | + tester (3) |
| large | 200-500 lines, 5+ files | + perf + external (5) |
| critical | 500+ lines OR touches auth/crypto/infra | all 6 + external (7) |

**Output format:**
```json
{
  "complexity": "medium",
  "lines_changed": 120,
  "files_changed": 4,
  "touches_sensitive": false,
  "recommended_reviewers": ["reviewer-architect", "reviewer-stylist", "reviewer-tester"],
  "summary": "Medium change: 120 lines across 4 files"
}
```

### `scripts/enhance_prompt.py`
Generate structured prompts for different analysis tasks. Takes a task type and optional context, returns a formatted prompt.

**Usage:** `uv run scripts/enhance_prompt.py <task_type> [--context "additional context"]`

**Supported task types:** `review`, `security`, `test-gen`, `explain`, `commit-msg`, `adr`

## Integration Pattern

Sub-agents and commands should use these scripts as building blocks:

1. **Discovery** (`discover_llm_clis.py`) — Called at the start of multi-model workflows to determine which CLIs are available for dispatch.
2. **Complexity** (`assess_complexity.py`) — Called by `/multi-review` to scale the number of reviewer agents.
3. **Prompts** (`enhance_prompt.py`) — Called by sub-agents and commands to get consistent, high-quality prompts for each task type.
