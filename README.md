# Jarvis — Claude Code customization pack

**Version 1.2.0** · see [CHANGELOG.md](CHANGELOG.md)

A small, opinionated set of slash commands, rules, and helper scripts that turn vanilla [Claude Code](https://claude.com/claude-code) into a more autonomous personal-assistant setup. Inspired by the [Hermes Agent](https://github.com/NousResearch/HermesAgent) idea of treating the agent as a long-running coworker that learns from experience and reconciles its own memory.

This is **personal infrastructure shared as-is**. There is no installer that "just works" without you wiring up your own keys and services. The repo is meant for you to fork or clone, then keep tweaking.

## What's inside

```
commands/                   slash commands (~/.claude/commands/<name>.md)
  capture-skill.md          turn the work just done into a reusable skill
  doctor.md                 health check (manual)
  go.md                     verify → simplify → ship to PR
  recall.md                 full-text search across past sessions
  security-sweep.md         adversarial security audit (hackSultan prompt)
  user-model-review.md      weekly review of accumulated user-memory

skills/                     multi-step skills (~/.claude/skills/<name>/SKILL.md)
  decompose/SKILL.md        long recording/spec → per-task PRDs → dependency map → queue

rules/                      auto-loaded rules (~/.claude/rules/<name>.md)
  self-improving-skills.md  when/how to write a new reusable skill
  definition-of-done.md     the 3 enforceable gates a big task must clear to ship
  context-saving.md         persist long task briefs into .claude-context/
  cross-project.md          read-only awareness of sibling projects under ~/Projects/
  gmail-send.md             docs for the gmail-send CLI helper
  mcp-usage.md              tool priority and MCP server cheatsheet
  project-structure.md      preferred Next.js / Supabase layout
  research-first-detail.md  research-before-implement workflow

hooks/                      settings.json hooks (~/.claude/hooks/<name>.sh)
  completion-gate.sh        PreToolUse: blocks "done/deployed" claims with no screenshot

docs/                       longer-form patterns
  fleet-tmux-orchestration.md  run many Claude Code instances in tmux as a coordinated fleet

scripts/                    helper scripts (~/.claude/scripts/ or /usr/local/bin)
  build_recall_index.py     SQLite FTS5 index over ~/.claude/projects/**/*.jsonl
  recall.py                 query the FTS5 index
  doctor_cron.py            non-interactive health check, alerts to Telegram on failure
  voice-gen.sh              Czech TTS with leading pause (edge-tts + ffmpeg)
  transcribe.sh             Groq Whisper API speech-to-text wrapper
  bot-monitor.sh            detect stuck Claude tmux instances, alert via Telegram
  merge-guard.sh            pre-merge governance check for GitHub PRs (draft / CI / blocker words)
  wa-send.sh                send WhatsApp via a WAHA container
  claude-self-upgrade.sh    restart a tmux Claude session to pick up a newer binary
  key-monitor.sh            daily probe of API tokens (GitHub/Google/Telegram/WAHA), alert on failure
  uptime-check.sh           poll URLs, alert only on up<->down transitions (SQLite state + quiet hours)
```

## Install

```bash
git clone https://github.com/<your-handle>/Jarvis.git ~/jarvis-source
mkdir -p ~/.claude/commands ~/.claude/rules ~/.claude/scripts \
         ~/.claude/hooks ~/.claude/skills/decompose
cp ~/jarvis-source/commands/*.md          ~/.claude/commands/
cp ~/jarvis-source/rules/*.md             ~/.claude/rules/
cp ~/jarvis-source/scripts/*              ~/.claude/scripts/
cp ~/jarvis-source/hooks/*.sh             ~/.claude/hooks/
cp ~/jarvis-source/skills/decompose/*.md  ~/.claude/skills/decompose/
chmod +x ~/.claude/scripts/*.py ~/.claude/scripts/*.sh ~/.claude/hooks/*.sh
```

`hooks/completion-gate.sh` only fires once you wire it into `~/.claude/settings.json`
as a `PreToolUse` hook on your outgoing message tool — see the header of the script
for the exact snippet and the `GATE_*` env knobs.

That's it for the files. Then bring the recall index online:

```bash
python3 ~/.claude/scripts/build_recall_index.py
# typical first run on ~2k sessions: ~50s, builds ~200MB SQLite db
```

And add cron entries (run `crontab -e`):

```cron
*/15 * * * * /usr/bin/python3 $HOME/.claude/scripts/build_recall_index.py >/dev/null 2>&1
55  5 * * *  /usr/bin/python3 $HOME/.claude/scripts/doctor_cron.py >/tmp/doctor.log 2>&1
30  6 * * *  $HOME/.claude/scripts/key-monitor.sh >/dev/null 2>&1
0   * * * *  $HOME/.claude/scripts/uptime-check.sh >/dev/null 2>&1
# Optional, only if you run multiple Claude Code instances in tmux:
*/5 * * * *  $HOME/.claude/scripts/bot-monitor.sh >/dev/null 2>&1
```

## Configure

`doctor_cron.py` and most shell helpers read `~/.claude/secrets/.env`. None of these values are checked into the repo:

| Variable | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | counted as a critical secret in `/doctor` |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | same |
| `TELEGRAM_BOT_TOKEN` | required for `/doctor`, `bot-monitor.sh`, `key-monitor.sh` and `uptime-check.sh` alerts |
| `TELEGRAM_CHAT_ID` | numeric chat id to receive alerts |
| `TELEGRAM_BOT_TOKENS` | optional CSV of extra bot tokens for `key-monitor.sh` to verify via `getMe` |
| `HEALTH_URLS` | CSV of `host|label` entries for `uptime-check.sh`, e.g. `example.com|Main,api.example.com|API` |
| `GROQ_API_KEY` | required by `transcribe.sh` (Whisper transcription) |
| `WAHA_API_KEY` | optional — only if you run a [WAHA](https://waha.devlike.pro/) WhatsApp container and want `wa-send.sh` |
| `WAHA_URL` | optional override, default `http://127.0.0.1:3100/api/sessions` |
| `POSTGRES_PORT` | optional override, default `5432` |
| `HOST_PROFILE` | optional, `main` or `small` (or your own — edit `_profile_expects()` in `doctor_cron.py`) |
| `CRITICAL_SECRETS` | optional CSV override of which env keys count as "critical" |

If you run a multi-host setup, set `HOST_PROFILE=main` on the box where Postgres and the Telegram bot live, and `HOST_PROFILE=small` where WAHA lives. Default is `main`.

## Use

Once installed, the slash commands are available in any Claude Code session:

| Command | What it does |
|---|---|
| `/go` | verify (typecheck/build/tests) → simplify changed files → commit + push + open PR |
| `/doctor` | one-screen interactive health check |
| `/recall <query>` | search every past Claude session by keyword (FTS5: `AND`/`OR`/`NEAR`/`"phrase"`) |
| `/capture-skill` | distill the work just done in this session into a new slash command |
| `/decompose` | break a long recording/spec into per-task PRDs + a dependency map, then load your queue |
| `/security-sweep` | adversarial security audit of the current codebase |
| `/user-model-review` | reconcile accumulated `~/.claude/projects/<project>/memory/` files |

Shell scripts you can call from anywhere (after `chmod +x` and PATH or symlink to `/usr/local/bin`):

| Script | Purpose |
|---|---|
| `voice-gen.sh "<text>" out.ogg` | render Czech TTS into a Telegram-voice-compatible `.ogg`; override `VOICE=` for another edge-tts voice |
| `transcribe.sh in.oga` | print the transcription on stdout; `LANG_CODE=en` for other languages |
| `bot-monitor.sh` | run from cron; alerts if any tmux Claude session goes idle while it has an in-flight task |
| `merge-guard.sh owner/repo 42` | dry-run; rejects merge if draft / unmergeable / CI not green / block-words in body |
| `merge-guard.sh owner/repo 42 --auto-merge` | actually squash-merges if all checks pass |
| `wa-send.sh 420XXXXXXXXX "text"` | send a WhatsApp message through your local WAHA container |
| `claude-self-upgrade.sh <tmux-session>` | from a sidecar pane, restart a stuck Claude session to pick up a newer binary |
| `key-monitor.sh` | run from cron; probes each configured API token and alerts only on failure |
| `uptime-check.sh` | run from cron; polls `HEALTH_URLS` and alerts only when a site flips up<->down |

## Orchestration economics

The most expensive way to run an agent is one smart model doing everything in one
context window. This pack leans on a cheaper, more reliable division of labour, and
on quality gates that catch the usual "looks done, isn't" failure.

**Smart-plans, cheap-executes.** A smart model (your orchestrator) writes a large,
detailed plan with strict rules, checks, and tests — and **reserves the final review
step for itself**. The plan is handed to cheaper models for execution. When they
report back, the smart model **takes the work over and reviews it** against what the
plan demanded — cross-model (a different model than the author), never self-approval
in the same context. It feels slightly slower but burns far fewer tokens, and big
tasks finish faster because cheap executors run in parallel.

**Caveman — terser agent-to-agent speech.** For the *execution* leg you can have
agents talk to each other in a clipped, telegraphic "caveman" style that drops
filler words. It saves roughly **15–25 % of output tokens** on mechanical work. It's
an external plugin ([`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman)) —
**this pack does not bundle it**, it just recommends it. Install and toggle per its
own docs (typically `npx -y github:JuliusBrussee/caveman`; the same command with
`-- --uninstall` removes it).

> **Rule: caveman OFF for specs, final reviews, and reports to the human.** Use it
> only for the mechanical execution leg (bulk code, refactors, extraction). Anything
> where precision or human-readability matters — writing the spec, every verification
> gate, and any message back to the user — stays in normal, full language.

**Definition of Done — 3 enforceable gates.** This is the key quality differentiator.
A non-trivial task is not "done" until it clears all three:

1. **Reverse-check against the original assignment** by an *independent* model — a
   matrix of every requested item → done / coded-but-not-deployed / missing.
2. **Tester confirms the user sees it in the UI** — clicking through the live app,
   not "the API returns 200" or "the flag is on".
3. **Visual proof to the human** — a screenshot of the live feature delivered with
   the milestone report, so the human never has to go digging.

`rules/definition-of-done.md` is the rule the agent reads; `hooks/completion-gate.sh`
nudges you when you try to claim "deployed/done" with no screenshot attached. See
**[docs/fleet-tmux-orchestration.md](docs/fleet-tmux-orchestration.md)** for the
multi-instance side of this: how to run several Claude Code workers in tmux under one
orchestrator — the piece that a single-instance setup can't match.

## Philosophy

Three patterns lifted from Hermes:

1. **Self-improving skills.** When you find yourself doing the same multi-step task a second or third time, formalize it. `rules/self-improving-skills.md` is the rule the agent reads to decide when to write one. `/capture-skill` is the on-demand version.
2. **Recall over memory.** `~/.claude/projects/.../memory/MEMORY.md` is the *conclusions* layer (small, hand-curated). `recall.db` is the *everything* layer (fast full-text over jsonl history). The agent picks the right one for the job.
3. **Silent green, loud red.** `doctor_cron.py`, `bot-monitor.sh`, `key-monitor.sh` and `uptime-check.sh` only ping Telegram when something is broken. No notification = healthy.

## Caveats

- The slash commands and shell scripts assume Linux + bash. They may need tweaks on macOS/Windows.
- The recall index is single-machine. If you want it shared across hosts, `scp recall.db` or rebuild from a synced `~/.claude/projects/`.
- `gh` CLI is required for `/go` to ship PRs and for `merge-guard.sh`. Without it, run the verify+simplify stages and ship manually.
- Several scripts call out to external services (Anthropic, GitHub, Telegram, Groq, WAHA). Each needs its own API key in `~/.claude/secrets/.env`.
- This repo contains **no secrets**. Never commit `~/.claude/secrets/.env`.

## Credits

- [Boris Cherny](https://github.com/bcherny) — original `/go` composite idea
- [Nous Research / Hermes Agent](https://github.com/NousResearch/HermesAgent) — self-improving skill pattern, session memory, host doctor
- [@hackSultan](https://x.com/hackSultan/status/2046269993898181081) — security audit prompt verbatim
- [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) — the token-saving "caveman" agent-speech plugin (recommended, not bundled)

## License

MIT — see [LICENSE](LICENSE).
