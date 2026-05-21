# Cross-Project Awareness

## Shared context
When working in any project under `~/Projects/`, a shared context file is available at `~/Projects/.shared-context.md`. This file is auto-generated every minute by `project-sync.py` and contains:
- All active projects with their git branch, last commit, systemd status, URLs, ports
- Shared services map (which Supabase instance, Raynet, Twilio is used by which project)
- Tech stack of each project

**Read this file** when you need context about other projects, especially when:
- Working with shared Supabase instances (beware of schema changes affecting other projects)
- Debugging cross-project issues (e.g., port conflicts, shared API keys)
- Understanding the full system architecture

## Rules
- **READ-ONLY access** to other projects: you may read files from `~/Projects/<other>/` but NEVER write to them
- **Shared DB instances:** Before any DB schema migration on a shared backend (Supabase, Neon, etc.), check which other projects use it and warn the user — track shared-instance project IDs in `.shared-context.md`
- **Port conflicts:** Check .shared-context.md before assigning new ports
- **Config source:** `~/Projects/.sync/config.json` has the full service mapping

## Notion Dev Dashboard
Project status is tracked in Notion "Dev Dashboard" database. The sync script updates auto-fields every minute but NEVER overwrites manual fields (Status, Notes, Blocked By).
