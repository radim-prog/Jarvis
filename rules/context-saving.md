# Saving context from important conversations

When the user gives a **10+ line detailed brief**, describes an important decision,
explains context, or specifies feature requirements → ALWAYS create a file:

```
.claude-context/YYYY-MM-DD-topic-name.md
```

## File format

```markdown
# [Topic name]
**Date:** YYYY-MM-DD
**Category:** [feature|design|architecture|business]

## Original assignment
[Verbatim quote or careful summary]

## Key decisions
- Decision 1
- Decision 2

## Reasoning and context
Why this was decided...

## Action items
- [ ] What was implemented
- [ ] What remains to do
```

## Rules

- Before starting work on a project: check whether `.claude-context/` exists;
  create it if not.
- Read the most recent files in `.claude-context/` to restore project context.
- Context files are READ-ONLY references — don't edit old ones, only add new ones.
