---
name: herdr
description: Controls the Herdr app and herdr-core (`hc`), including spaces, tabs, panes, terminals, agents, communication between agents, other machines, and app mods. Use for Herdr operations, troubleshooting, and agent handoffs that a workflow skill assigns, not incidental background work.
---

# Herdr

herdr-core (`hc`) runs every terminal and agent and keeps them alive when the window closes. The `herdr-app` window shows them as spaces, tabs, and panes. The `herdr` command is a separate, older TUI; do not use it to control the app.

Before the first Herdr operation in a task, read the installed manual: `hc --skill`, plus `herdr-app --skill` when changing the screen. The manuals define syntax and behavior and win if they differ from this skill, which adds only the rules for how we use Herdr.

If `$HC_TERMINAL_ID` is unset, you are not running in herdr-core: documentation, help, and setup diagnosis remain available, but do not control an unrelated live session. Otherwise confirm with `hc get "$HC_TERMINAL_ID"` that its folder and agent match this task.

Never run bare `hc` (it opens an attach picker). Never stop, restart, or update the user's core or app unless asked, because that affects every terminal.

## Communicating with agents

Herdr transports terminal input and reports observed state; it gives another agent no shared conversation context and no permission to act outside its assignment.

- When the user asks to contact an existing agent, resolve its address, folder, and current task from `hc ls`, `hc get`, and a scoped read. If several match, ask.
- Say who is sending, the requested outcome, the exact checkout and evidence, the allowed actions, and the reply you want. State whether this is a status request, new assignment, correction, or cancellation, so a status question does not replace ongoing work.
- Build messages as quoted data, not interpolated shell code. For a long message, load a temporary UTF-8 file into a quoted shell variable; `hc send` takes text, not a file path.
- Sending to a `working` agent can queue or steer its turn. Use `--if idle` unless that is what you intend.
- Keep one coordinator responsible for collecting results, and avoid agents synchronously waiting on each other.
- A settled status does not prove the task succeeded; read the answer and its evidence.
- When an agent is `blocked`, resolve routine questions within existing authority and leave approvals requiring the user to the user. Do not use `hc send --force` or approval keys to get past a permission decision.

## Starting agents

- Follow the task's delegation scope and the repository's role rules. An agent in a Herdr terminal inherits no role, so its first message must carry the whole assignment and limits.
- Use the agent kind the user requested, otherwise this harness. Do not invent model or effort overrides.
- Use a separate checkout when concurrent edits require it, and do not let two agents edit the same files without agreed ownership.
- When the user asks to see a helper, open it in the window with `herdr-app do agent.focus`.

## Changing what the user sees

Unless the user asks to switch to a new space or tab, record the focused pane before creating it and refocus that pane afterward, so the user stays where they were working:

```bash
pane=$(herdr-app status | python3 -c 'import json, sys; print(json.load(sys.stdin)["focused_pane"])')
# create the space or tab
herdr-app do pane.focus --pane "$pane"
```

`pane.split` takes no task: send it to the returned terminal after `hc wait` shows the agent ready. Closing a space, tab, or pane ends its terminals, so close only disposable ones created for this task or ones the user asked to close, after confirming their work has ended, and pass `--confirmed true` only then.

## Other machines

Adding or changing machines (`hc machine add|login|update|rm`) is setup, done only when asked. SSH authentication requiring human input belongs in the user's terminal.
