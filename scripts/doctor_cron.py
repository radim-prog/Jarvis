#!/usr/bin/env python3
"""Non-interactive health check — runs on cron, alerts to Telegram only when something is broken.

Suggested cron entry:
  55 5 * * *   /usr/bin/python3 /root/.claude/scripts/doctor_cron.py >/tmp/doctor.log 2>&1

Configuration via ~/.claude/secrets/.env:
  TELEGRAM_BOT_TOKEN   = <bot token from @BotFather>          required for alerts
  TELEGRAM_CHAT_ID     = <your numeric chat id>               required for alerts
  WAHA_API_KEY         = <waha API key>                       required if HOST_PROFILE includes waha
  HOST_PROFILE         = main | small | <custom>              optional, default "main"
  CRITICAL_SECRETS     = ANTHROPIC_API_KEY,GITHUB_TOKEN,...   optional override

The HOST_PROFILE flag lets you split a multi-machine setup so the alert engine
only complains about services that are *expected* on this host. Default profile
"main" expects Postgres + a Telegram bot process locally; profile "small"
expects WAHA. Adjust `_profile_expects()` to fit your topology.
"""
import json
import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib import request

SECRETS = Path.home() / ".claude" / "secrets" / ".env"


def env() -> dict:
    out = {}
    if SECRETS.exists():
        for line in SECRETS.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                k, _, v = line.partition("=")
                out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def _profile_expects(service: str, profile: str) -> bool:
    """Return True if `service` is supposed to run locally under `profile`."""
    expectations = {
        "main":  {"postgres", "telegram_bot"},
        "small": {"waha"},
    }
    return service in expectations.get(profile, set())


def check_secrets(e: dict) -> tuple[bool, str]:
    critical_csv = e.get("CRITICAL_SECRETS", "ANTHROPIC_API_KEY,GITHUB_PERSONAL_ACCESS_TOKEN,TELEGRAM_BOT_TOKEN")
    critical = [s.strip() for s in critical_csv.split(",") if s.strip()]
    missing = [k for k in critical if not e.get(k)]
    return (not missing, f"missing: {missing}" if missing else f"{len(e)} keys, all critical present")


def check_gh() -> tuple[bool, str]:
    if not shutil.which("gh"):
        return True, "gh CLI not installed (skipped)"
    r = subprocess.run(["gh", "auth", "status"], capture_output=True, text=True, timeout=10)
    ok = "Logged in" in r.stderr or "Logged in" in r.stdout
    return ok, "logged in" if ok else "NOT logged in"


def check_google_token() -> tuple[bool, str]:
    p = Path.home() / ".claude" / "secrets" / "google_token.json"
    if not p.exists():
        return True, "missing (skipped — only checked if present)"
    try:
        d = json.loads(p.read_text())
        scopes = d.get("scopes", [])
        return True, f"present, {len(scopes)} scopes"
    except Exception as ex:
        return False, f"unparseable: {ex}"


def check_postgres(profile: str) -> tuple[bool, str]:
    if not _profile_expects("postgres", profile):
        return True, f"skipped (profile={profile})"
    pg = shutil.which("pg_isready")
    if not pg:
        return True, "pg_isready not installed (skipped)"
    port = os.environ.get("POSTGRES_PORT", "5432")
    r = subprocess.run([pg, "-h", "localhost", "-p", port], capture_output=True, text=True, timeout=5)
    ok = r.returncode == 0
    return ok, f"{port} accepting" if ok else f"{port} NOT reachable"


def check_telegram_bot(profile: str) -> tuple[bool, str]:
    if not _profile_expects("telegram_bot", profile):
        return True, f"skipped (profile={profile})"
    r = subprocess.run(["pgrep", "-fc", "telegram"], capture_output=True, text=True)
    n = int(r.stdout.strip() or "0")
    return n > 0, f"{n} processes" if n > 0 else "no telegram bot process"


def check_waha(e: dict, profile: str) -> tuple[bool, str]:
    if not _profile_expects("waha", profile):
        return True, f"skipped (profile={profile})"
    api_key = e.get("WAHA_API_KEY")
    if not api_key:
        return False, "WAHA_API_KEY missing"
    url = e.get("WAHA_URL", "http://127.0.0.1:3100/api/sessions")
    try:
        req = request.Request(url, headers={"X-Api-Key": api_key})
        with request.urlopen(req, timeout=3) as r:
            r.read()
        return True, "reachable"
    except Exception as ex:
        return False, f"unreachable: {type(ex).__name__}"


def check_disk() -> tuple[bool, str]:
    s = shutil.disk_usage("/")
    pct = (s.used / s.total) * 100
    return pct < 90, f"{pct:.0f}% used"


def check_recall_index() -> tuple[bool, str]:
    p = Path.home() / ".claude" / "recall.db"
    if not p.exists():
        return True, "no recall.db (skipped — only checked if present)"
    age_h = (time.time() - p.stat().st_mtime) / 3600
    return age_h < 24, f"size {p.stat().st_size // (1024 * 1024)}MB, age {age_h:.1f}h"


def alert_telegram(e: dict, body: str) -> None:
    token = e.get("TELEGRAM_BOT_TOKEN")
    chat = e.get("TELEGRAM_CHAT_ID")
    if not token or not chat:
        print("(TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID missing — cannot alert)", file=sys.stderr)
        return
    data = json.dumps({"chat_id": chat, "text": body}).encode()
    req = request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with request.urlopen(req, timeout=10) as r:
            r.read()
    except Exception as ex:
        print(f"(telegram alert failed: {ex})", file=sys.stderr)


def main():
    e = env()
    profile = e.get("HOST_PROFILE", "main")
    checks = [
        ("secrets", check_secrets(e)),
        ("github", check_gh()),
        ("google_token", check_google_token()),
        ("postgres", check_postgres(profile)),
        ("telegram_bot", check_telegram_bot(profile)),
        ("waha", check_waha(e, profile)),
        ("disk", check_disk()),
        ("recall_index", check_recall_index()),
    ]
    failed = [(name, msg) for name, (ok, msg) in checks if not ok]
    summary = "\n".join(f"{'✓' if ok else '✗'} {name}: {msg}" for name, (ok, msg) in checks)
    host = socket.gethostname()

    if "--always" in sys.argv:
        print(summary)
        return

    if failed:
        body = f"⚠ Doctor [{host}] — {len(failed)} issue(s):\n\n" + "\n".join(
            f"✗ {n}: {m}" for n, m in failed
        ) + "\n\nFull:\n" + summary
        print(body)
        alert_telegram(e, body)
    else:
        print("Healthy.")
        # Silent on success — only alert on failure.


if __name__ == "__main__":
    main()
