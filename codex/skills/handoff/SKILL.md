---
name: handoff
description: Create a normal new Codex task when the user asks the current task to hand off, continue, or transfer part or all of its work to a fresh task or session. Use a self-contained prompt in the saved parent local project. Do not use for the app's Hand off action that moves the same task between Local and Worktree, for forks, or for internal subagent delegation.
---

# Handoff

Create a new task as if the user opened the saved parent local project and typed a self-contained continuation prompt.

**Announce at start:** "Using the handoff skill to create a fresh local task."

## Resolve the destination

1. Proceed only after the user explicitly requests a new task or session.
2. Resolve the repository's parent checkout with `git worktree list --porcelain`. Use the checkout represented by the main `worktree` entry, not a Codex-managed or feature worktree.
3. Use the project-listing tool to find the saved parent local project whose primary path exactly matches that checkout.
4. If that saved parent project is unavailable, stop and ask the user to add it as a local project. Do not substitute another project.

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

When no implementation worktree exists, state that the task starts in the saved parent local project and that an approved implementation workflow may later create its worktree under `<project-root>/.worktrees/`.

## Create the task

Use the thread-creation tool with the saved parent project's ID and `environment: { type: "local" }`. Never fork the current task, select a Worktree environment, target a saved worktree project, or use the app's Hand off action. Omit model and thinking settings unless the user explicitly requests them.

Leave the current task, parent checkout, worktrees, and retained evidence unchanged. Report the new task and the exact parent project and active worktree, if any, after creation succeeds.
