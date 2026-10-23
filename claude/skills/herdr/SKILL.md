---
name: herdr
description: Control Herdr panes, workspaces, terminals, and agents, including communication between agents and saved SSH machines. Use for Herdr operations or troubleshooting, not incidental background work or delegation.
---

# Herdr

Use the `herdr` CLI to operate terminals and coordinate agents within the user's requested scope. Herdr transports terminal input and reports observed state; it does not give another agent shared conversation context or permission to act outside its assignment.

## Resolve context and capabilities

For live control, require `HERDR_ENV=1` and resolve the caller with `herdr pane current --current`. Compare the returned agent and working directory with this task. Inherited environment variables can belong to a different pane; if context disagrees, resolve the intended target before writing input or changing layout. Never guess from the UI's focused pane. Outside Herdr, documentation, CLI help, and setup diagnosis remain available; do not control an unrelated live session.

Start with `herdr status` and the relevant command group's `--help`. The installed CLI defines syntax; the running server may be older and lack a method. A missing method is not permission to update or restart the server. Never run bare `herdr` for discovery: it attaches the TUI. Use `--help` on nested commands too; omitting arguments can execute commands with defaults.

Discover only the scope needed:

```bash
herdr workspace list
herdr pane current --current
herdr tab list --workspace "$workspace_id"
herdr pane list --workspace "$workspace_id"
herdr agent list
```

Use IDs returned by the selected server, not sidebar position or example IDs. IDs are opaque and scoped to a server/session. Creation responses contain:

| Operation | New pane ID |
| --- | --- |
| `workspace create` | `.result.root_pane.pane_id` |
| `tab create` | `.result.root_pane.pane_id` |
| `pane split` | `.result.pane.pane_id` |
| `pane move` | `.result.move_result.pane.pane_id` |

After a move, use the returned ID; inherited workspace/tab IDs can be stale. `--current` resolves the original pane alias, but does not establish that the calling process is the agent you intend to control. Most control responses are JSON; `pane read` and `agent read` print terminal text directly.

## Communicate with an existing agent

Prefer an existing agent when the user asks to contact it. Resolve its machine/session, live name or pane ID, repository, and current task from `agent list`, `agent get`, and a scoped output read. Agent targets accept a unique live name or pane ID, not a terminal ID or an agent kind. If several agents match the request, clarify before sending to one.

```bash
herdr agent get "$target"
herdr agent read "$target" --source visible
herdr agent prompt "$target" "$message" --wait --timeout 60000
herdr agent read "$target" --source recent-unwrapped --lines 120
```

Build the message as quoted data, not interpolated shell code. For a long message, write a temporary UTF-8 file and load it into a quoted shell variable; `agent prompt` takes text, not a file-path argument.

Give the recipient enough context to act independently: the sender, requested outcome or question, exact checkout and relevant evidence, allowed actions, and desired reply. Share relevant excerpts or same-machine file paths rather than assuming the other agent sees this conversation. State whether this is a status request, new assignment, correction, or cancellation so a status question does not accidentally replace ongoing work.

For a direct reply to another Herdr agent, include the resolved return machine/session and agent name or pane ID. A reply is another `agent prompt`, not a mailbox operation. Keep one coordinator responsible for collecting results; avoid agents synchronously waiting on each other. Normally read the recipient's answer after waiting instead of creating a reply loop. Notifications are user-facing toasts, not agent messages.

Inspect foreground state before sending: a retained agent identity can belong to a suspended process. `idle` and `done` are useful readiness signals, but screen detection can miss dialogs. When already `working`, a prompt can queue or steer work according to that agent's runtime; send only when that is intended. Herdr's wait may then finish on the existing turn, so read the response to establish which request completed.

`agent prompt --wait` submits text and Enter together, then waits for `idle`, `done`, or `blocked`. From a non-working state it requires observed activity; `agent_prompt_stalled` means activity was not seen, not that no input arrived. A timeout, stalled response, or lost connection requires inspecting state/output before any resubmission. Resume waiting without resending:

```bash
herdr agent wait "$target" --timeout 60000
```

Use `--until` only when an exact state matters. Wait through the execution tool's running-process handle rather than repeatedly listing agents. A settled state is not proof of task success; read the answer and its evidence. `unknown` proves neither readiness nor completion.

A `blocked` agent needs its dialog inspected. Resolve routine questions within existing authority; leave approvals requiring the user to the user. Never send Enter or approval keys blindly. Use `agent send-keys` for a deliberate UI response, cancellation, or interruption, not `pane run` to bypass an agent-state rejection.

For active agents use `--source visible`. Larger `recent-unwrapped` reads may recover alternate-screen history only when idle and can temporarily scroll the application. If the full result remains unavailable, ask the agent to write it to a temporary Markdown file and return the path, then read it on that same machine.

## Start an agent or ordinary command

Creating helpers must follow the task's delegation scope and repository role rules. Use native role tools when the workflow requires a native implementer or reviewer; an ordinary agent in a Herdr pane does not inherit that role. Do not replace required native reviews with a generic prompted terminal agent.

For a requested helper, default to a sibling pane in the same tab and checkout. Inspect `pane layout` first: split wide panes right and narrow/tall panes down. Preserve focus and pass the intended cwd explicitly. Use a separate checkout when concurrent edits require it under the repository workflow; do not have two agents edit the same files without agreed ownership.

```bash
herdr pane layout --pane "$caller_pane"
created=$(herdr pane split "$caller_pane" --direction right --cwd "$PWD" --no-focus)
helper_pane=$(printf '%s\n' "$created" | jq -r '.result.pane.pane_id')
herdr pane process-info --pane "$helper_pane"
herdr pane read "$helper_pane" --source visible
herdr agent start helper --kind claude --pane "$helper_pane"
```

Replace `right`, `helper`, and the kind as appropriate. Names must be unique among live agents and match `[a-z][a-z0-9_-]{0,31}`. Use the user's requested agent kind; otherwise use this harness. Read `agent start --help` for supported kinds; native arguments go after `--`. Preserve model and effort preferences instead of inventing overrides.

`agent start` requires an existing interactive shell prompt with no foreground command or agent. Success means the expected agent was detected and ready, not that work was assigned. On `agent_not_ready`, inspect the retained named agent instead of launching another. Then submit the assignment with `agent prompt`.

For a shell command, use the pane surface instead:

```bash
herdr pane run "$helper_pane" "$command_text"
herdr pane wait-output "$helper_pane" --match "$completion_marker" --timeout 60000
herdr pane read "$helper_pane" --source recent-unwrapped --lines 120
```

`pane run` acknowledges queued input, not command completion. `wait-output` immediately searches existing output, so use a run-specific marker and inspect the actual exit status/result. The marker must be produced by completion, not merely present in echoed input. `pane send-text` sends literal text without Enter; `pane send-keys` sends keys such as `enter`, `esc`, or `ctrl+c`. Do not inject shell commands into a busy pane or an agent prompt.

## Layout and other controls

Use command help for options rather than memorizing the entire API:

| Need | Commands |
| --- | --- |
| Inspect or organize projects | `workspace list/get/create/rename/focus/close` |
| Separate terminal layouts | `tab list/get/create/rename/focus/close` |
| Rearrange panes | `pane layout/neighbor/resize/zoom/swap/move` |
| Manage Git-backed workspaces | `worktree list/create/open/remove` |
| Diagnose agent detection | `agent explain`, `integration status` |
| Inspect plugins and actions | `plugin list --json`, `plugin action list`, `plugin log list` |
| Invoke an installed action | `plugin action invoke` |
| Notify the user | `notification show TITLE --body TEXT` |
| Inspect sessions | `session list --json`, `api snapshot` |

Use `--no-focus` for background creation or moves. Explicitly select the workspace on `tab create`; default targeting can use someone else's focus. Workspace/tab creation already creates a root pane, so reuse that pane before splitting.

`worktree create` changes Git state; supply the repository-required `--path` rather than accepting an unrelated default location. `workspace close` closes terminals; `worktree remove` also removes the checkout. Do not add `--force`, `--group`, or `--trust-repository` merely to get past a refusal. Close only disposable resources created for this task or resources the user asked to close, after confirming their work has ended. CLI closes may not show the TUI's confirmation.

Plugin invocation can execute arbitrary installed commands; inspect the action and apply the same authority as running its command. Integration installation changes harness hooks/configuration and is a setup action, not a remedy to apply automatically whenever detection is uncertain. Metadata reports change display labels; they do not prove execution or lifecycle completion. Do not forge `report-agent` state to make a wait succeed.

## Saved machines and sessions

```bash
herdr machine list --json
herdr machine status mini --json
herdr --machine mini agent list
herdr --machine mini agent get "$remote_target"
herdr --machine mini agent prompt "$remote_target" "$message" --wait --timeout 60000
herdr --machine mini agent read "$remote_target" --source recent-unwrapped --lines 120
```

`mini` is an example saved profile label: use one returned by discovery. A label is case-sensitive; an SSH hostname alone is not a saved machine selector. Keep the same machine selector on every command in the exchange. TUI machine selection does not change CLI routing, and local `--current`/IDs do not identify a remote pane. Remote file paths refer to the remote filesystem.

Forwarding uses the profile's saved session and requires a running compatible remote server. Do not combine `--machine` with `--session` or `--remote`; it never falls back to Local. Local session management, configuration/installation, and interactive attachment are not forwarded. Diagnose failures with machine status and the remote CLI as appropriate; do not restart, upgrade, or replace a server without authorization. SSH authentication requiring human input belongs in the user's terminal.

Detaching leaves processes running; stopping a server terminates them. Never kill the main Herdr process to refresh settings or test this skill. Use an explicitly scoped disposable named session for experiments requiring a server, and stop only that test session afterward.

## Documentation and deeper automation

Based on the official stable documentation and bundled skill inspected on 2026-10-23. Recheck installed help when behavior differs:

- [Documentation index](https://herdr.dev/llms.txt): follow the exact-revision raw links for the needed topic instead of loading the whole manual.
- [Agent automation](https://herdr.dev/docs/agent-automation/): identity, prompt submission, waits, and transcript reads.
- [CLI reference](https://herdr.dev/docs/cli-reference/): control commands and options.
- [Socket API](https://herdr.dev/docs/socket-api/): custom automation and long-lived event subscriptions.
- [Connecting machines](https://herdr.dev/docs/connecting-machines/): saved profiles, routing, and connection diagnosis.
- [Agent guide](https://herdr.dev/agent-guide.md): first-time setup and troubleshooting.

Prefer CLI wrappers. For an actual event subscriber or missing CLI operation, read the socket documentation and `herdr api schema --json` before implementing a client. Events are not a durable agent mailbox; `events_lost` requires resubscription and a fresh authoritative snapshot, not invented delivery guarantees. Do not build a daemon or messaging framework for a one-off prompt/wait/read exchange.
