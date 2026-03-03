---
description: Prepare handover summary for new conversation when running out of context
---

# Handover Preparation

You are preparing a handover summary for a new conversation. This happens when the current conversation is running out of context and needs to be continued in a fresh session.

## Phase 1: Gather State

Collect the following information:

### Task State
- Capture any active TodoWrite items (pending and in-progress)
- Identify the primary task/goal of this session
- Note any subtasks or next steps that were planned

### Session Knowledge
- **Debugging findings**: What was learned while investigating (even if not solved)
- **Failed approaches**: What was tried and didn't work (to avoid repeating)
- **Key decisions**: Important choices made and their rationale
- **Blockers**: Any issues preventing progress

## Phase 2: Write Handover

Write a handover summary file to `/tmp/claude-handover.md`:

```markdown
# Conversation Handover - [Brief Title]

## Session Context
- **Date**: [today's date]
- **Primary Goal**: [what we were trying to accomplish]

## Completed Work ✅
[list of completed items with brief descriptions]

## In Progress 🔄
[current task and its state]
[any partial work or findings]

## Pending Tasks 📋
[remaining todo items]

## Key Findings This Session
- [important discoveries]
- [failed approaches to avoid]
- [decisions made and why]

## Blockers / Unknowns ❓
[anything blocking progress]
[questions that need answers]

## Next Steps for New Session
1. [specific first action]
2. [follow-up actions]
```

## Phase 3: Generate Continuation Prompt

Provide a copy-pasteable prompt for the new conversation:

```
I'm continuing work from a previous session. Please read the handover file at /tmp/claude-handover.md and:
1. Summarize your understanding of what was accomplished and what needs to be done
2. Ask any clarifying questions before proceeding
3. Resume work on the pending tasks
```

## Handover Quality Checklist

Before finishing, verify:
- [ ] All in-progress work is documented with enough detail to resume
- [ ] Failed approaches noted (so they won't be repeated)
- [ ] Key decisions and rationale recorded
- [ ] Continuation prompt is specific and actionable
- [ ] Next session can start without user re-explaining the task
