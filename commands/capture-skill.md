---
description: Turn the work just completed in this session into a reusable skill or slash command
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /capture-skill — distill recent work into a skill

Invoked when the user wants to formalize the procedure we just executed so next time it's a single command.

## Steps

1. **Identify the procedure** — scan back through the recent conversation (since the last `/clear` or last completed task) and identify:
   - What goal did we accomplish?
   - Which steps generalized vs which were one-off (specific date, specific person, specific file)?
   - Which tools were essential?

2. **Pick scope and name** — ask one clarifying question if unclear:
   - **Slash command** (`~/.claude/commands/<name>.md`) for one-shot procedures
   - **Skill** (`~/.claude/skills/<name>/SKILL.md`) for procedures with assets / sub-files
   - **Project-local** (`<project>/.claude/commands/<name>.md`) if it only makes sense there

   Name format: short, verb-based, kebab-case (`digest-morning`, not `MorningDigestSkill`).

3. **Check for existing** — `Glob ~/.claude/commands/<name>.md` first. If exists, propose edit instead of overwrite.

4. **Write the file** — follow the format from `~/.claude/rules/self-improving-skills.md`:
   - Frontmatter: `description`, `allowed-tools`
   - Sections: When to use, Steps, Examples, Safety
   - **No session-specific context** (dates, names, paths from this conversation)
   - Steps as imperative numbered list

5. **Confirm in 1 line** — `Skill saved: ~/.claude/commands/<name>.md — invoke with /<name>`.

## Examples

User: "create a skill from what you just did with the morning digest"
→ Identifies digest pipeline, names it `digest-morning`, writes file, confirms.

User: "remember this as the WhatsApp send procedure"
→ Asks: "draft-first protocol or direct send? In what scope (global or project-local)?"

## Safety

- Don't capture skills that just restate CLAUDE.md / rules — those are already loaded each turn.
- Don't capture skills containing secrets, tokens, or live URLs that decay.
- Don't capture if the procedure was a debugging dead-end — only successful workflows.
