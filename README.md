# Jarvis — oh-my-claudecode

> **Turn Claude Code into a persistent, multi-agent operator — not just a chatbot.**

[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple.svg)](https://claude.com/claude-code)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)](#install)

**Jarvis** is a production-tested customization pack for [Claude Code](https://claude.com/claude-code)
(searchable as *oh-my-claudecode*): slash commands, auto-loaded rules, hooks, and
helper scripts that wire Claude Code into a long-running, self-improving, multi-agent
operator.

Most Claude Code setups are single-instance, single-task. Jarvis adds the
infrastructure layer that most people build piece by piece and give up on halfway:
**fleet orchestration** (multiple Claude instances coordinated via tmux), **session
recall** (FTS5 full-text search across every past conversation), **self-improving
skills** (the agent writes its own reusable procedures), and **enforceable quality
gates** (no more "done" claims without proof).

---

## The idea in one paragraph

Claude Code already runs in your terminal. What it lacks out of the box is memory that
scales, a way to delegate to parallel workers, and quality enforcement that actually
fires. Jarvis is the missing runtime layer: a SQLite FTS5 index over every session
you've ever had (`/recall`), a tmux-based fleet pattern with a shared task queue and
watchdog (bot-monitor, fleet docs), skills that teach themselves (`/capture-skill`),
and a PreToolUse hook that blocks "deployed!" reports with no screenshot attached.
The result is an agent that remembers what it decided three months ago, can delegate
to five parallel workers, and can't lie to you about whether it's actually done.

---

## What's inside

```
commands/                     slash commands → ~/.claude/commands/<name>.md
  go.md                       verify (typecheck/build/tests) → simplify → PR
  recall.md                   FTS5 full-text search over all past sessions
  doctor.md                   one-screen health check (secrets, MCP, services, disk)
  capture-skill.md            distill recent work into a reusable skill/command
  security-sweep.md           adversarial security audit (red-team prompt)
  user-model-review.md        reconcile, deduplicate, and prune accumulated memory

skills/                       multi-step skills → ~/.claude/skills/<name>/SKILL.md
  decompose/SKILL.md          /decompose: spec/recording → per-task PRDs → dependency
                              map → task queue (no GitHub Issues required)

rules/                        auto-loaded rules → ~/.claude/rules/<name>.md
  definition-of-done.md       3 enforceable gates — no task is "done" without them
  self-improving-skills.md    when and how to write a reusable skill
  research-first-detail.md    research-before-implement workflow with examples
  context-saving.md           persist long briefs into .claude-context/
  cross-project.md            read-only awareness of sibling projects
  mcp-usage.md                tool priority and MCP server cheatsheet
  project-structure.md        preferred Next.js / Supabase layout
  gmail-send.md               docs for the gmail-send CLI helper

hooks/                        settings.json hooks → ~/.claude/hooks/<name>.sh
  completion-gate.sh          PreToolUse: nudges when "deployed/done" is claimed
                              without a screenshot — generalized, ENV-configurable

docs/                         longer-form patterns
  fleet-tmux-orchestration.md how to run multiple Claude Code instances in tmux
                              as a coordinated fleet: one orchestrator + workers,
                              dispatch protocol, shared queue, watchdog

scripts/                      helper scripts → ~/.claude/scripts/ or /usr/local/bin
  build_recall_index.py       SQLite FTS5 index over ~/.claude/projects/**/*.jsonl
  recall.py                   query the FTS5 index (AND/OR/NEAR/"phrase"/--since)
  doctor_cron.py              non-interactive health check, Telegram alert on fail
  bot-monitor.sh              detect stuck Claude tmux instances, alert via Telegram
  key-monitor.sh              daily probe of API tokens; alert only on failure
  uptime-check.sh             poll URLs; alert only on up↔down transitions
  voice-gen.sh                TTS via edge-tts + ffmpeg (Telegram voice-note output)
  transcribe.sh               Groq Whisper API speech-to-text wrapper
  merge-guard.sh              pre-merge governance check for GitHub PRs
  wa-send.sh                  send WhatsApp messages via a WAHA container
  claude-self-upgrade.sh      restart a tmux Claude session (binary upgrade helper)
```

---

## Why this is different

Most Claude Code "setups" are just `CLAUDE.md` files with a list of rules. This is a
runtime infrastructure layer.

| Problem | What this pack adds |
|---|---|
| "What did we decide about X last month?" | `/recall` — FTS5 index over every session you've ever had |
| One instance, one thing at a time | Fleet orchestration — orchestrator + N workers in tmux |
| Agent claims "done", it isn't | Definition of Done — 3 enforceable gates, hook that fires |
| Same multi-step task done twice by hand | `/capture-skill` — agent writes the skill itself |
| Long recording → vague plan → missing half | `/decompose` — spec → per-task PRDs → dependency graph |
| "Is anything broken?" before a long run | `/doctor` + `doctor_cron.py` — one-screen health check |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Your machine                                                    │
│                                                                  │
│  tmux                                                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  orchestrator session                                    │   │
│  │  claude (reads rules/ + commands/ + hooks/)              │   │
│  │  • plans, delegates, reviews                             │   │
│  │  • runs /recall, /doctor, /capture-skill, /decompose     │   │
│  └────────┬───────────────────────┬──────────────────────────┘   │
│           │ dispatch (tmux send)   │ read state (capture-pane)   │
│  ┌────────▼──────────┐  ┌────────▼──────────┐                  │
│  │  worker session A │  │  worker session B │  ...             │
│  │  claude in ~/proj │  │  claude in ~/proj │                  │
│  │  Read→Edit→Build  │  │  Read→Edit→Build  │                  │
│  │  reports DONE #id │  │  reports DONE #id │                  │
│  └───────────────────┘  └───────────────────┘                  │
│                                                                  │
│  Shared task queue (SQLite or JSON file)                        │
│  Watchdog cron → bot-monitor.sh → Telegram alert on stall      │
│                                                                  │
│  ~/.claude/recall.db  (FTS5 index, refreshed every 15 min)     │
│  ~/.claude/projects/*/memory/MEMORY.md  (curated conclusions)  │
└─────────────────────────────────────────────────────────────────┘
```

Memory has two layers: `MEMORY.md` (small, hand-curated conclusions) and `recall.db`
(fast full-text over the complete JSONL history). The agent picks the right one for
the job — memory for "what we always do", recall for "what did we decide that one time".

---

## Key features

### /recall — search every past session

```bash
# In any Claude Code session:
/recall "CORS error AND fixed"
/recall "database schema decision" --since 2026-03-01
/recall "auth" --project my-api --role user
```

FTS5 supports full boolean (`AND`/`OR`), `NEAR(a b, 5)`, `"quoted phrases"`, and
prefix `term*`. The index is built by `build_recall_index.py` over every
`~/.claude/projects/**/*.jsonl` file — incremental refresh every 15 minutes via cron,
full rebuild with `--full`. Typical first run on ~2,000 sessions: ~50 s, ~200 MB.

### Fleet orchestration — one orchestrator, many workers

```bash
tmux new-session -d -s main      'claude'
tmux new-session -d -s worker-api 'cd ~/Projects/my-api && claude'
tmux new-session -d -s worker-web 'cd ~/Projects/my-web && claude'
```

The orchestrator dispatches tasks, workers execute them and report back. Each worker
owns its own project directory and memory — no shared context window, no context
bloat. See `docs/fleet-tmux-orchestration.md` for the dispatch protocol, shared queue
pattern, and watchdog setup.

### /capture-skill — the agent that improves itself

After solving a multi-step problem, run `/capture-skill`. Claude reads back the
session, distills the repeatable procedure, and writes a new slash command to
`~/.claude/commands/`. Next time, one command instead of full reasoning.

`rules/self-improving-skills.md` defines the trigger conditions (same pattern
appearing for the third time, explicit user request, 5+ tool call procedure) so the
agent does this automatically — not just when asked.

### /decompose — long recording or spec → actionable queue

```
/decompose recording.oga
```

Transcribes → extracts 5–10 discrete tasks → spawns a sub-agent per task to write
its own mini-PRD (acceptance criteria, layers touched, risks) → compares them
pairwise to produce a dependency graph (wave 1 in parallel, wave 2 depends on wave 1)
→ loads everything into your task queue in the right order.

### Definition of Done — 3 enforceable gates

No non-trivial task is "done" until it clears all three:

1. **Reverse-check against the original assignment** by an independent model — a
   matrix of every requested item → `done+deployed / coded-but-not-deployed / missing`,
   plus a completion % weighted by the user's stated priorities.
2. **Tester confirms the user sees it in the UI** — click-through of the live app,
   not "API returns 200" or "the flag is on".
3. **Visual proof to the human** — a screenshot of the live feature attached to the
   milestone report.

`hooks/completion-gate.sh` fires as a `PreToolUse` hook on your messaging tool and
nudges the agent when it tries to send "deployed / done / live" with no screenshot.
It never blocks communication — the reminder goes to stderr; the hard enforcement
is in the rule and the workflow phase.

### Orchestration economics — smart plans, cheap executes

The most expensive way to run an agent is one smart model doing everything in one
context window. The recommended pattern:

1. **Smart model writes a large, detailed plan** — with strict rules, checks, tests,
   and a reserved final review step.
2. **Cheap model executes** in parallel workers.
3. **Smart model reviews** the output — cross-model (different model than the author),
   never self-approval in the same context.

For the execution leg, the [Caveman plugin](https://github.com/JuliusBrussee/caveman)
by JuliusBrussee saves ~15–25% of output tokens by having agents talk in clipped
telegraphic style to each other. **This pack does not bundle it** — install separately
with `npx -y github:JuliusBrussee/caveman`. Caveman OFF for specs, final reviews,
and any message to the human.

### Silent green, loud red — monitoring without noise

`doctor_cron.py`, `bot-monitor.sh`, `key-monitor.sh`, and `uptime-check.sh` only
send a Telegram alert when something breaks. No alert = healthy. All read
configuration from `~/.claude/secrets/.env` and degrade gracefully when inputs
are absent.

---

## Install

```bash
git clone https://github.com/radim-prog/Jarvis.git ~/jarvis
cd ~/jarvis
bash install.sh
```

> If you fork the repo, replace the URL with your fork's URL.

`install.sh` copies everything into `~/.claude/`, builds the recall index, and prints
suggested cron entries. Manual steps:

```bash
# 1. Add cron entries (crontab -e):
*/15 * * * * /usr/bin/python3 $HOME/.claude/scripts/build_recall_index.py >/dev/null 2>&1
55   5 * * * /usr/bin/python3 $HOME/.claude/scripts/doctor_cron.py >/tmp/doctor.log 2>&1
30   6 * * * $HOME/.claude/scripts/key-monitor.sh >/dev/null 2>&1
0    * * * * $HOME/.claude/scripts/uptime-check.sh >/dev/null 2>&1
# Optional — only if you run multiple Claude Code instances in tmux:
*/5  * * * * $HOME/.claude/scripts/bot-monitor.sh >/dev/null 2>&1

# 2. Create ~/.claude/secrets/.env and add your keys (see Configure below)

# 3. Wire the completion gate into ~/.claude/settings.json (see hooks/completion-gate.sh header)
```

### Requirements

- Linux or macOS, bash
- Python 3.8+
- `claude` CLI ([Claude Code](https://claude.com/claude-code))
- `gh` CLI — for `/go` (PR creation) and `merge-guard.sh`
- `tmux` — for fleet orchestration
- `sqlite3` — for recall index and uptime state
- `edge-tts` + `ffmpeg` — optional, only for `voice-gen.sh`
- `curl` — for alert scripts

---

## Configure

All scripts read `~/.claude/secrets/.env` (KEY=VALUE format, never committed to git).

| Variable | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | counted as a critical secret in `/doctor` |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | same |
| `TELEGRAM_BOT_TOKEN` | alerts from `doctor_cron.py`, `bot-monitor.sh`, `key-monitor.sh`, `uptime-check.sh` |
| `TELEGRAM_CHAT_ID` | numeric chat id to receive alerts |
| `TELEGRAM_BOT_TOKENS` | optional CSV of extra bot tokens for `key-monitor.sh` to verify |
| `HEALTH_URLS` | CSV of `host\|label` pairs for `uptime-check.sh` (e.g. `example.com\|Main`) |
| `GROQ_API_KEY` | required by `transcribe.sh` (Whisper transcription) |
| `WAHA_API_KEY` | optional — only if you run a [WAHA](https://waha.devlike.pro/) WhatsApp container |
| `WAHA_URL` | optional override, default `http://127.0.0.1:3100/api/sessions` |
| `POSTGRES_PORT` | optional override, default `5432` |
| `HOST_PROFILE` | `main` or `small` (or your own — edit `_profile_expects()` in `doctor_cron.py`) |
| `CRITICAL_SECRETS` | optional CSV override of which env keys count as "critical" |

For multi-host setups: `HOST_PROFILE=main` on the box where Postgres and the
Telegram bot live, `HOST_PROFILE=small` where WAHA lives.

---

## Use

Once installed, slash commands are available in any Claude Code session:

| Command | What it does |
|---|---|
| `/go` | verify (typecheck/build/tests) → simplify changed files → commit + push + open PR |
| `/doctor` | one-screen interactive health check |
| `/recall <query>` | FTS5 full-text search across every past session |
| `/capture-skill` | distill recent work in this session into a new slash command |
| `/decompose` | break a long recording/spec into per-task PRDs + dependency map |
| `/security-sweep` | adversarial red-team audit of the current codebase |
| `/user-model-review` | reconcile, deduplicate, and prune memory files |

Shell scripts (after `chmod +x` and PATH or symlink to `/usr/local/bin`):

| Script | Purpose |
|---|---|
| `voice-gen.sh "<text>" out.ogg` | TTS to Telegram-voice-compatible `.ogg`; `VOICE=` to change voice |
| `transcribe.sh in.oga` | print transcription on stdout; `LANG_CODE=en` for other languages |
| `bot-monitor.sh` | cron; alerts if any tmux Claude session goes idle mid-task |
| `merge-guard.sh owner/repo 42` | dry-run; rejects merge if draft / CI not green / block-words |
| `merge-guard.sh owner/repo 42 --auto-merge` | squash-merges if all checks pass |
| `wa-send.sh 1XXXXXXXXXX "text"` | send WhatsApp via local WAHA container |
| `claude-self-upgrade.sh <tmux-session>` | restart a session from a sidecar pane (binary upgrade) |
| `key-monitor.sh` | cron; probes each API token, alerts only on failure |
| `uptime-check.sh` | cron; polls `HEALTH_URLS`, alerts only when a site flips state |

---

## Demo transcript

```
You: /recall "database migration AND rollback"

Claude: Found 3 hits across 2 projects:
  2026-03-14  user  my-api    a3b7c9d1  «… we decided rollback by dumping before
                                          every ALTER using pg_dump …»
  2026-04-02  asst  my-api    f8e2a101  «… pg_dump -Fc before migration, stored in
                                          /backups/pre-<timestamp>.dump …»
  2026-05-20  user  my-store  91bc4d22  «… same approach, confirmed it works …»

Conclusion: standard pattern is pg_dump -Fc before every ALTER, stored locally.
Want me to add that to the migration script?
```

```
You: We just figured out the right way to deploy. Make it a skill.

Claude: Reading back this session...

I extracted 6 repeatable steps: verify CI green → pg_dump backup → Prisma migrate
→ restart service → smoke test → Telegram notify. None of them are session-specific.

Saved: ~/.claude/commands/deploy-safe.md — invoke with /deploy-safe
```

```
You: /doctor

=== Claude Code health ===
Secrets:     ✓ 12 keys, all critical present
GitHub:      ✓ your-handle logged in
Google:      ✓ present, 8 scopes
MCP:         ✓ 9 servers configured, 9 reachable
Telegram:    ✓ bot running (1 process)
Postgres:    ✓ 5432 accepting connections
Disk:        ✓ 54% used
Memory:      ✓ 6.1G available
Recall DB:   ✓ 847MB, age 0.2h
Errors:      ✓ no fatal errors

Healthy.
```

---

## Philosophy

Three ideas borrowed from [Hermes Agent](https://github.com/NousResearch/HermesAgent):

1. **Self-improving skills.** When you find yourself doing the same multi-step task a
   second or third time, formalize it. `rules/self-improving-skills.md` is the rule
   the agent reads to decide when to write one. `/capture-skill` is the on-demand
   version.

2. **Recall over memory.** `~/.claude/projects/.../memory/MEMORY.md` is the
   *conclusions* layer (small, hand-curated). `recall.db` is the *everything* layer
   (fast full-text over complete JSONL history). The agent picks the right one:
   memory for standing decisions, recall for "what did we say about that one edge case".

3. **Silent green, loud red.** The monitoring scripts only alert when something breaks.
   No notification = healthy. Noise kills attention — alert only when it matters.

---

## Caveats

- Slash commands and shell scripts assume Linux + bash. May need tweaks on macOS.
- The recall index is single-machine. To share across hosts, `scp recall.db` or
  rebuild from a synced `~/.claude/projects/`.
- `gh` CLI is required for `/go` to create PRs and for `merge-guard.sh`. Without it,
  run the verify+simplify stages and ship manually.
- Several scripts call external services (Anthropic, GitHub, Telegram, Groq, WAHA).
  Each needs its own API key in `~/.claude/secrets/.env`.
- **This repo contains no secrets.** Never commit `~/.claude/secrets/.env`.

---

## Credits

- [Boris Cherny](https://github.com/bcherny) — original `/go` composite idea
- [Nous Research / Hermes Agent](https://github.com/NousResearch/HermesAgent) — self-improving skills pattern, session memory, host doctor concept
- [@hackSultan](https://x.com/hackSultan/status/2046269993898181081) — security audit prompt (verbatim, with attribution)
- [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) — token-saving agent-speech plugin (recommended, not bundled)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
