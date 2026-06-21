# Project structure

## Where to work

- **~/Projects/** — working directory (local disk) for all active projects
- Cloud storage (Drive, Dropbox, etc.) — documents only (PDFs, images, media) — NEVER `node_modules/`
- Code backup: git + GitHub, not cloud storage

## Preferred Next.js layout

```
~/Projects/my-project/
├── app/
│   ├── (dashboard)/          # Route groups
│   └── api/                  # API routes
├── lib/
│   ├── utils.ts
│   ├── db.ts                 # Database client
│   └── types/                # Shared types
├── components/
│   └── ui/                   # UI component library
├── public/
├── .claude-context/          # Saved conversation context
├── node_modules/             # Fine on local disk, never commit / sync
└── .next/                    # Build cache
```

## Rules

- `node_modules/` and `.next/` NEVER go to cloud storage
- Every project has its own `.gitignore` with `.env*`, `node_modules/`, `.next/`
- For database admin clients, use a dedicated file (e.g. `lib/db-admin.ts`) with
  the service-role credential separate from the public client
