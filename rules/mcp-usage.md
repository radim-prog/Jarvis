# MCP a nástroje - detailní pravidla

## Priorita nástrojů

| Pořadí | Nástroj | Typ | Cena | Kdy použít |
|--------|---------|-----|------|------------|
| 1. | **WebFetch** | Built-in | Zdarma | Známé URL, první volba (99% případů) |
| 2. | **WebSearch** | Built-in | Zdarma | Vyhledávání, neznáš URL |
| 3. | **Brave Search** | MCP | Placený | Jen když WebSearch nestačí |
| 4. | **Playwright** | MCP | Zdarma | Jen JS-heavy weby kde WebFetch vrátí prázdný obsah |

## Rozhodovací strom

1. Znám URL? → **WebFetch**
2. Potřebuji vyhledat? → **WebSearch**
3. WebSearch nestačí? → **Brave Search** (šetři - placené API)
4. WebFetch vrátil prázdný obsah (React/Vue/Angular app)? → **Playwright MCP**

## Brave Search optimalizace

- Placený API ($5/1000 requestů) - šetři!
- Kombinuj dotazy: místo 5 separátních udělej 1 komplexní
- Cache výsledky v rámci session
- Pokud znáš URL, jdi přímo přes WebFetch

## Playwright MCP pravidla

- NIKDY jako první volba - vždy zkus WebFetch nejdřív
- Preferuj microsoft/playwright-mcp (accessibility tree based)
- Použij pro: screenshot, interakci s webem, JS-rendered obsah
- Nepoužívej pro: statické stránky, API dokumentace, GitHub

## Aktivní MCP servery

| Server | Účel |
|--------|------|
| memory | Persistentní knowledge graph |
| brave-search | Webové vyhledávání (placené) |
| playwright | Browser automation |
| github | GitHub API rozšíření |
| supabase | Supabase management |
| notion (2x) | Notion API (starý + nový Anthropic MCP) |
| context7 | Dokumentace knihoven |
| filesystem | Rozšířené souborové operace |
| vercel | Vercel deployment |
