# MCP servers and tools — usage rules

## Tool priority

| Priority | Tool | Type | Cost | When to use |
|---|---|---|---|---|
| 1 | **WebFetch** | Built-in | Free | Known URL — first choice (99% of cases) |
| 2 | **WebSearch** | Built-in | Free | Search when you don't know the URL |
| 3 | **Brave Search** | MCP | Paid | Only when WebSearch doesn't return enough |
| 4 | **Playwright** | MCP | Free | Only for JS-heavy sites where WebFetch returns empty content |

## Decision tree

1. Know the URL? → **WebFetch**
2. Need to search? → **WebSearch**
3. WebSearch not enough? → **Brave Search** (paid — use sparingly)
4. WebFetch returned empty content (React/Vue/Angular SPA)? → **Playwright MCP**

## Brave Search tips

- Paid API ($5/1,000 requests) — combine queries instead of making 5 separate calls
- Cache results within the session
- If you know the URL, use WebFetch directly

## Playwright MCP rules

- NEVER as first choice — always try WebFetch first
- Prefer `microsoft/playwright-mcp` (accessibility tree based, lower cost)
- Use for: screenshots, web interaction, JS-rendered content
- Do NOT use for: static pages, API documentation, GitHub

## MCP server catalogue

The pack does not prescribe which MCP servers you run — add what your stack needs.
Common choices (listed as examples, not requirements):

| Server | Purpose |
|---|---|
| `brave-search` | Paid web search |
| `playwright` | Browser automation |
| `github` | GitHub API extensions |
| `filesystem` | Extended file operations |
| `context7` | Library documentation lookup |
| `memory` | Persistent knowledge graph |

Add your MCP servers to `~/.claude/settings.json` under `mcpServers`.
`/doctor` will report how many are configured and reachable.
