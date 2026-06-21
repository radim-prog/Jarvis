# Contributing

Thanks for your interest. This is a personal infrastructure pack shared
publicly — contributions are welcome, but keep the scope tight.

## What fits

- Bug fixes in scripts or slash commands
- New slash commands or skills that follow the existing format
- Improvements to the fleet orchestration pattern
- Platform portability (macOS, Windows/WSL)
- Better documentation or examples

## What doesn't fit

- Integrations with specific proprietary services or cloud vendors
  (those belong in your own fork or private overlay)
- New dependencies that aren't widely available on Linux/macOS
- Anything requiring secrets or credentials in the repo

## How to contribute

1. Fork the repo and create a branch from `main`.
2. Make your change. Keep each PR focused on one thing.
3. For new scripts: follow the header comment style in existing `.sh` files
   (one-line purpose, usage, configuration, cron suggestion where relevant).
4. For new slash commands: use the frontmatter format
   (`description`, `allowed-tools`, then the command body).
5. Run the secret sweep before opening a PR:
   ```bash
   grep -rn --include="*.md" --include="*.sh" --include="*.py" \
     -E "(password|secret|api.?key|bearer|private)" . \
     | grep -v "\.git" \
     | grep -v "YOUR_\|TELEGRAM_\|ANTHROPIC_\|GITHUB_\|GROQ_\|WAHA_\|POSTGRES_"
   ```
   Output should be empty or only contain placeholder variable names.
6. Open a PR with a clear description of the problem it solves.

## Code style

- Shell scripts: `set -euo pipefail`, quote variables, `shellcheck`-clean where
  practical.
- Python: stdlib only (no third-party imports except for optional features like
  `google-auth`, which are guarded by try/except).
- Markdown: 80-column wrap preferred; code blocks with language hints.

## Security

- **Never include real credentials, IPs, hostnames, or personal identifiers.**
- If a script references an external service, use environment variables loaded
  from `~/.claude/secrets/.env` — never hardcoded.
- If you find a security issue, open a private advisory rather than a public
  issue.

## License

By contributing, you agree that your contributions will be licensed under the
MIT License that covers this project.
