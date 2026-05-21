# Jarvis — Claude Code customization pack

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

rules/                      auto-loaded rules (~/.claude/rules/<name>.md)
  self-improving-skills.md  when/how to write a new reusable skill
  context-saving.md         persist long task briefs into .claude-context/
  cross-project.md          read-only awareness of sibling projects under ~/Projects/
  gmail-send.md             docs for the gmail-send CLI helper
  mcp-usage.md              tool priority and MCP server cheatsheet
  project-structure.md      preferred Next.js / Supabase layout
  research-first-detail.md  research-before-implement workflow

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
```

## Install

```bash
git clone https://github.com/<your-handle>/Jarvis.git ~/jarvis-source
mkdir -p ~/.claude/commands ~/.claude/rules ~/.claude/scripts
cp ~/jarvis-source/commands/*.md   ~/.claude/commands/
cp ~/jarvis-source/rules/*.md      ~/.claude/rules/
cp ~/jarvis-source/scripts/*       ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.py ~/.claude/scripts/*.sh
```

That's it for the files. Then bring the recall index online:

```bash
python3 ~/.claude/scripts/build_recall_index.py
# typical first run on ~2k sessions: ~50s, builds ~200MB SQLite db
```

And add cron entries (run `crontab -e`):

```cron
*/15 * * * * /usr/bin/python3 $HOME/.claude/scripts/build_recall_index.py >/dev/null 2>&1
55  5 * * *  /usr/bin/python3 $HOME/.claude/scripts/doctor_cron.py >/tmp/doctor.log 2>&1
# Optional, only if you run multiple Claude Code instances in tmux:
*/5 * * * *  $HOME/.claude/scripts/bot-monitor.sh >/dev/null 2>&1
```

## Configure

`doctor_cron.py` and most shell helpers read `~/.claude/secrets/.env`. None of these values are checked into the repo:

| Variable | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | counted as a critical secret in `/doctor` |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | same |
| `TELEGRAM_BOT_TOKEN` | required for `/doctor` and `bot-monitor.sh` alerts |
| `TELEGRAM_CHAT_ID` | numeric chat id to receive alerts |
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

## Philosophy

Three patterns lifted from Hermes:

1. **Self-improving skills.** When you find yourself doing the same multi-step task a second or third time, formalize it. `rules/self-improving-skills.md` is the rule the agent reads to decide when to write one. `/capture-skill` is the on-demand version.
2. **Recall over memory.** `~/.claude/projects/.../memory/MEMORY.md` is the *conclusions* layer (small, hand-curated). `recall.db` is the *everything* layer (fast full-text over jsonl history). The agent picks the right one for the job.
3. **Silent green, loud red.** `doctor_cron.py` and `bot-monitor.sh` only ping Telegram when something is broken. No notification = healthy.

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

## License

MIT — see [LICENSE](LICENSE).
