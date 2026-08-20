---
name: handoff
description: Create a normal new Codex task when the user asks the current task to hand off, continue, or transfer part or all of its work to a fresh task or session. Use a self-contained prompt in the exact saved parent project with a Local environment, regardless of whether the app classifies that project's host as local or remote. Do not use for the app's Hand off action that moves the same task between Local and Worktree, for forks, or for internal subagent delegation.
---

# Handoff

Create a new task as if the user opened the saved parent project, selected the Local environment, and typed a self-contained continuation prompt.

**Announce at start:** "Using the handoff skill to create a fresh local task."

## Resolve the destination

1. Proceed only after the user explicitly requests a new task or session.
2. Resolve the repository's parent checkout with `git worktree list --porcelain`. Use the checkout represented by the main `worktree` entry, not a Codex-managed or feature worktree.
3. Resolve the current task's host before selecting a project. Prefer the app's current-thread host metadata; if only host names are available, compare the project host with `hostname`.
4. Use the project-listing tool and require both the exact parent path and the current task's host. Accept that match whether its `projectKind` is `"local"` or `"remote"`; that field describes how the app reaches the configured host, not whether the task uses the checkout or a worktree.
5. If the current host cannot be resolved, or no project matches both host and path, stop and report the mismatch. Do not substitute a different path or host or tell the user to add a project that already exists on another host.

## Inspect the continuation state

Inspect the current task evidence and the relevant repository with read-only commands. Capture:

- the user's requested continuation scope;
- the issue or goal and the governing plan, specification, or handoff paths;
- completed work, actual verification, remaining work, blockers, and approval boundaries;
- evidence that must be preserved;
- the parent checkout's absolute path; and
- each relevant worktree's absolute path, branch, HEAD, and working-tree state.

If implementation already has an active worktree, identify the exact worktree used by the existing work. If more than one worktree could plausibly be active and the current task does not resolve the ambiguity, ask the user which one to continue.

## Build the prompt

Write a concise, self-contained prompt that transfers exactly the work the user requested. Do not introduce total-versus-partial handoff modes or ownership state.

When an active implementation worktree exists, the prompt must:

- identify its absolute path, branch, HEAD, and working-tree state;
- direct the new task to reuse that exact worktree with explicit workdirs;
- prohibit creating a replacement worktree or editing the parent checkout; and
- preserve uncommitted work and retained evidence.

When no implementation worktree exists, state that the task starts in the saved parent project's Local environment and that an approved implementation workflow may later create its worktree under `<project-root>/.worktrees/`.

## Create the task

Use the thread-creation tool with the saved parent project's ID and `environment: { type: "local" }`. Never fork the current task, select a Worktree environment, target a saved worktree project, or use the app's Hand off action. Omit model and thinking settings unless the user explicitly requests them.

Leave the current task, parent checkout, worktrees, and retained evidence unchanged. Report the new task and the exact parent project and active worktree, if any, after creation succeeds.
