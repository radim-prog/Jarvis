# Fleet orchestration with tmux — running multiple Claude Code instances on one machine

This is the part that turns a single-instance setup into a *fleet*. Sub-agents
(the `Agent` / Task tool inside one session) are great for short, bounded,
read-mostly work that finishes and returns. But a sub-agent shares the parent's
context window, dies when its task ends, and can't be a long-lived, independently
addressable worker. For persistent, parallel, long-running work you want **multiple
full Claude Code instances**, each in its own tmux session, coordinated by one
"main" agent.

Without this pattern, a single instance simply can't reach the same throughput or
endurance — one context window, one attention budget, one thing at a time. With it,
a main orchestrator can keep several workers busy for hours while staying lightweight
itself.

> Nothing here requires any specific tokens, IDs, or hostnames. It's a pattern you
> adapt to your own machine and naming.

## When to use more sessions vs. sub-agents

| Use a **sub-agent** (Task tool) | Use a **separate tmux session** |
|---|---|
| Bounded research / search / review | Long-running work (hours, days) |
| Work that returns a result and ends | A worker you want to address repeatedly |
| You want the result back *in this context* | You want to protect the orchestrator's context |
| One-shot, no persistence needed | Persistent identity / its own memory & queue |
| Cheap fan-out, then merge | True parallelism across independent modules |

Rule of thumb: if it finishes in one turn and you need its output inline, sub-agent.
If it's a coworker you'll talk to again, give it its own session.

## Roles

- **Main / orchestrator** — one instance. It does triage, planning, delegation, and
  integration. It does **not** write the bulk of the code itself; it keeps its
  context clean for coordination. Think team-lead, not IC.
- **Workers** — one or more instances, each pinned to a project or a module. Each
  worker runs its own Read → Edit → build → verify loop, and reports back when done.

Keep one *active* task per worker at a time. A worker shouldn't context-switch
mid-task; finish or explicitly block, then take the next item.

## Spawning the fleet

Each instance is just `claude` started inside its own named tmux session. Give every
session a stable, descriptive name so you can target it later.

```bash
# Start the orchestrator
tmux new-session -d -s main 'claude'

# Start workers, one per project / module
tmux new-session -d -s worker-api  'cd ~/Projects/my-api  && claude'
tmux new-session -d -s worker-web  'cd ~/Projects/my-web  && claude'
```

Notes:
- Start each worker in the directory it owns. A worker should only edit files inside
  its own project — that's your guard against two workers fighting over the same
  files (use git worktrees if two must touch the same repo).
- If your messaging/channel integration needs a per-instance state directory, export
  a distinct one before launching each session so they don't collide.

## Dispatching a message into another session

You "talk" to a worker by typing into its tmux pane. The reliable way is to send the
text and the Enter keypress **separately** — a single multi-line send can be captured
as a paste and not submitted.

```bash
dispatch() {
  local session="$1"; shift
  local msg="$*"
  tmux send-keys -t "$session" "$msg"   # type the line
  sleep 0.3
  tmux send-keys -t "$session" Enter    # submit it
}

dispatch worker-api "Implement the /health endpoint per the PRD in .claude-context/, then report DONE #12."
```

Gotchas learned the hard way:
- **Single-line only.** Send each line as its own `send-keys` call; don't embed
  newlines — they get treated as a paste, not a submit.
- **Separate Enter.** Send the text, pause briefly, then send `Enter` on its own.
- **Always end a dispatch with a report-back instruction** ("report DONE #id when
  finished"). Don't rely on polling to notice completion.

## Reading a worker's state

To check on a worker without interrupting it, capture its pane:

```bash
tmux capture-pane -t worker-api -p | tail -20
```

This is also how a stuck-instance monitor works: hash the last few lines over time,
and if the hash hasn't changed while the worker is supposed to be busy, alert. See
`scripts/bot-monitor.sh` in this pack for a ready-made version.

## A shared task queue makes it robust

tmux dispatch alone is fire-and-forget. Pair it with a small shared queue (a SQLite
table, a JSON file — anything both the orchestrator and workers can read/write):

- Each task has an id, an assignee, and a status (`queued` / `in_progress` / `done` /
  `blocked`).
- The orchestrator enqueues; workers pick up, flip to `in_progress`, and write back
  `done #id` or `blocked #id <reason>`.
- A watchdog (cron + `bot-monitor.sh`) catches anything that silently stalls.

This is what makes the fleet survive context compaction and restarts: the work lives
in the queue, not only in any one session's head. A worker can be restarted fresh and
pick up exactly where the queue says it should.

## Restarting a worker

To pick up a newer Claude binary or recover a wedged session, restart the session
rather than resuming in place. A fresh start is almost always safer than `--resume`;
the in-context thread is disposable because the durable state lives in the queue and
in `~/.claude/.../memory/`. See `scripts/claude-self-upgrade.sh` for a helper that
restarts a tmux session from a sidecar pane.

## Quick checklist

- [ ] One orchestrator session; it coordinates, it doesn't grind code.
- [ ] One worker per project/module, started in that directory.
- [ ] Distinct tmux session names; distinct state dirs if your channel needs them.
- [ ] Dispatch = single-line text, pause, separate Enter, end with "report back".
- [ ] A shared queue holds the source of truth, not any one session.
- [ ] A watchdog alerts on silent stalls.
- [ ] Restart workers fresh; don't hoard state in a single session.
