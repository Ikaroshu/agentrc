---
name: merge
description: Merges a verified branch or pull request into main, pushes it, runs required follow-ups, and cleans up. Use when the user approves or asks for a merge or the cleanup of a merged branch.
---

# Merge Workflow

Merge with `git merge --no-ff` or `gh pr merge --merge`. Never rebase unless asked.

Merge approval also covers pushing `main` unless the user asks for a local-only merge, the checks and follow-ups the repository's Git Workflow assigns to merging, and removing the merged branch and its clean worktree. Ask before any other consequential follow-up. Delete a remote branch only when authorized.

## Before merging

Confirm that the implementation owner (whoever built the candidate: this agent, or the Codex implementer after a handoff) recorded verification after the last code change, and that any code review accepted the same commit. If that evidence is missing or names a different commit, return the candidate to its owner rather than testing it yourself; a merge-stage rerun would only duplicate accepted evidence. Run only checks the repository assigns to the merge stage.

## When something fails

Return candidate-related diagnosis and repair to the implementation owner, and never push a known regression. Disclose unrelated or pre-existing failures before deciding whether authorization covers the push. If a follow-up fails, report it rather than claiming success.

Stop cleanup and report if the worktree is dirty, the branch is not fully merged, or ownership is unclear.
