# Self-improving skills

Inspired by Hermes Agent (Nous Research) — the agent should turn experience into reusable procedure files so the same task next time costs 1 command instead of full reasoning.

## Trigger: When to write a skill

Write or update a skill when:

1. You just solved a **non-trivial multi-step task** that took 5+ tool calls and would likely repeat — examples: "morning digest pipeline", "task-tracker insert", "messaging draft+verify+send", "tmux dispatch into another session", "voice-to-TTS recap loop".
2. The user says any of: "create a skill", "you must know this", "we'll be doing this often", "remember this as", or describes a procedure prescriptively.
3. You hit the same pattern for the **third time** in different conversations — formalize it.

## Where to write

- **Slash command** (one-shot, project-agnostic, returns immediately to user): `~/.claude/commands/<name>.md`
- **Skill** (richer, multi-step, may have sub-files / scripts): `~/.claude/skills/<name>/SKILL.md`
- **Project-local** (only meaningful in that project): `<project>/.claude/commands/<name>.md`

Default to slash command unless the procedure needs scripts, assets, or sub-files.

## Format

```markdown
---
description: <one-line purpose>
allowed-tools: <comma-separated list of tools the skill may call>
---

# /<name> — <short tagline>

<When to use it / when NOT to use it.>

## Steps
1. <concrete step 1>
2. <concrete step 2>
...

## Examples
<at least 1 invocation showing input → output>

## Safety / edge cases
<things that could go wrong>
```

## Don't

- Don't write skills that just re-state instructions from CLAUDE.md or rules — those are already loaded.
- Don't write skills for one-off operations that won't repeat.
- Don't bloat with "best practices" lectures — write the literal procedure.
- Don't reference specific session context, dates, or transient state — skills must be reusable.

## Update over duplicate

Before writing a new skill, check `~/.claude/commands/` and `~/.claude/skills/` for an existing one to extend. Edit > duplicate.

## Capture pattern (when the user asks you to capture work just done)

When the user says "create a skill from what you just did" or similar:
1. Re-read the conversation since the last `/clear` to identify the procedure.
2. Distill steps that would repeat next time (skip session-specific details).
3. Pick a name (verb-based: `/digest-morning`, `/task-insert`, `/recap-voice`).
4. Write the file in the right location.
5. Confirm in 1 line: path + how to invoke.
