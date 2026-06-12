# Changelog

All notable changes to this customization pack are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/), and the
project aims to follow [Semantic Versioning](https://semver.org/).

## [1.2.0] — 2026-06-12

### Added
- `rules/definition-of-done.md` — the 3 enforceable gates a non-trivial task must
  clear before it can be called "done": (1) an independent model reverse-checks the
  result against the *original* assignment, (2) a Tester confirms the user actually
  sees it in the live UI (not "API returns 200"), and (3) a screenshot of the live
  feature reaches the human with the milestone report.
- `hooks/completion-gate.sh` — a PreToolUse hook that nudges you when you try to
  report "deployed / done / live" about a feature with no screenshot attached.
  Generalized with `GATE_REPLY_TOOL` / `GATE_CHAT_ID` / `GATE_LOG` env knobs; wire it
  into `settings.json` on your own messaging tool.
- `skills/decompose/SKILL.md` (`/decompose`) — break a long recording/spec into 5–10
  discrete tasks, give each its own mini-PRD, build a dependency map (waves: what's
  first / parallel / blocked), and load them into your own task queue. No GitHub
  Issues required.
- `docs/fleet-tmux-orchestration.md` — the "secret sauce": how to run multiple Claude
  Code instances in tmux as a coordinated fleet (one orchestrator + workers), dispatch
  messages between sessions, and when to prefer separate sessions over sub-agents.

### Changed
- README gains an **Orchestration economics** section: smart-plans / cheap-executes,
  the **Caveman** token-saving agent-speech plugin (recommended, not bundled — caveman
  OFF for specs, final reviews, and reports to the human), and the Definition of Done.
- `install.sh` and the README install steps now also copy `hooks/` and
  `skills/decompose/`, and explain wiring the completion gate into `settings.json`.

## [1.1.0] — 2026-06-11

### Added
- `scripts/key-monitor.sh` — daily sanity check of the API tokens your setup
  depends on (GitHub via `gh`, Google OAuth, Telegram bots, optional WAHA).
  Each credential is probed with a harmless read-only call; only failures
  trigger a Telegram alert. Every check is skipped when its inputs are absent,
  so you only probe what you actually use.
- `scripts/uptime-check.sh` — poll a list of URLs (`HEALTH_URLS`) and alert on
  state transitions only (up→down / down→up, with outage duration on
  recovery). State is tracked in a small SQLite db, and quiet hours
  (`QUIET_START`/`QUIET_END`) suppress night-time pings to a log.

### Notes
- Both new scripts follow the existing "silent green, loud red" convention and
  read configuration from `~/.claude/secrets/.env`. They degrade gracefully:
  with no token configured they print a `would-alert` line to stderr instead
  of sending anything.

## [1.0.0] — 2026-04-25

### Added
- Slash commands: `/go`, `/doctor`, `/recall`, `/capture-skill`,
  `/security-sweep`, `/user-model-review`.
- Auto-loaded rules: `self-improving-skills`, `context-saving`,
  `cross-project`, `gmail-send`, `mcp-usage`, `project-structure`,
  `research-first-detail`.
- Helper scripts: `build_recall_index.py`, `recall.py`, `doctor_cron.py`,
  `voice-gen.sh`, `transcribe.sh`, `bot-monitor.sh`, `merge-guard.sh`,
  `wa-send.sh`, `claude-self-upgrade.sh`.
- `install.sh`, README, MIT LICENSE.

[1.2.0]: ../../releases/tag/v1.2.0
[1.1.0]: ../../releases/tag/v1.1.0
[1.0.0]: ../../releases/tag/v1.0.0
