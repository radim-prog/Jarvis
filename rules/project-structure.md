# Struktura projektů

## Kde pracovat

- **~/Projects/** - pracovní složka (LOKÁLNÍ DISK) pro všechny aktivní projekty
- **Google Drive** - JEN dokumenty (PDF, obrázky, videa) - NIKDY node_modules!
- Záloha kódu: GitHub, NE Google Drive

## Preferovaná Next.js struktura

```
~/Projects/muj-projekt/
├── app/
│   ├── (dashboard)/          # Route groups
│   └── api/                  # API routes
├── lib/
│   ├── utils.ts
│   ├── supabase.ts
│   └── types/                # Sdílené typy
├── components/
│   └── ui/                   # shadcn components
├── public/
├── .claude-context/          # Zachovaný kontext konverzací
├── node_modules/             # OK na lokálním disku
└── .next/                    # Build cache
```

## Pravidla

- `node_modules/` a `.next/` NIKDY do Google Drive
- Každý projekt má svůj `.gitignore` s `.env.local`, `node_modules/`, `.next/`
- Supabase projekty: `lib/supabase-admin.ts` pro service_role client
