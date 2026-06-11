# Changelog

All notable changes to this customization pack are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/), and the
project aims to follow [Semantic Versioning](https://semver.org/).

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

[1.1.0]: ../../releases/tag/v1.1.0
[1.0.0]: ../../releases/tag/v1.0.0
