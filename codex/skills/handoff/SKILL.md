---
name: handoff
description: Transfer requested work to a normal fresh Codex task in the exact saved parent project and Local environment. Do not use for forks, internal delegation, or the app's Hand off action between Local and Worktree.
---

# Handoff

Create a fresh task in the saved parent project and Local environment with a self-contained continuation prompt.

**Announce at start:** "Using the handoff skill to create a fresh local task."

## Resolve

1. Proceed only after an explicit request for a new task or session.
2. Find the parent checkout with `git worktree list --porcelain`; use the first `worktree` entry, never a feature or Codex-managed worktree.
3. Resolve the current task's host before selecting a project. Prefer thread metadata; otherwise compare host names with `hostname`.
4. List projects and require both the exact parent path and the current task's host, whether its `projectKind` is `"local"` or `"remote"`. That field describes host access, not environment type.
5. If host resolution or the exact match fails, stop and report it; substitute no path or host, and do not ask the user to recreate a project that exists elsewhere.

## Inspect the continuation state

Read current task evidence and repository state. Capture:

- requested scope, goal or issue, and governing spec or handoff paths;
- completed and remaining work, actual verification, blockers, approval boundaries, and retained evidence; and
- the parent path plus each relevant worktree's path, branch, HEAD, and status.

Identify any active implementation worktree. Ask if multiple plausible worktrees remain ambiguous.

## Build the prompt

Transfer exactly the requested work without inventing handoff modes or ownership state.

When an active implementation worktree exists, the prompt must:

- state its absolute path, branch, HEAD, and status;
- require the task to reuse that exact worktree with explicit workdirs;
- forbid a replacement worktree or parent-checkout edits; and
- preserve uncommitted work and evidence.

Without one, state that the task starts in the saved parent's Local environment and an approved implementation may later create `<project-root>/.worktrees/`.

## Create the task

Use the thread-creation tool with the saved parent project ID and `environment: { type: "local" }`. Never fork the current task, choose a Worktree environment, target a saved worktree project, or use the app's Hand off action. Omit model and thinking settings unless requested.

Leave current state unchanged. After success, report the new task, exact parent project, and active worktree if any.
