---
name: merge
description: Run Shu's merge workflow for a branch or pull request. Use when the user asks to merge, finish a branch, merge a PR, or clean up after merging. Reads the project's Git Workflow, resolves the exact target, reuses exact-candidate evidence when valid, verifies after merge, and performs only authorized follow-ups.
---

# Merge Workflow

Verify the candidate, merge, verify the integrated result, and clean up. Handles both local merges and PR merges.

**Announce at start:** "Running merge workflow."

## Step 1: Read Project Config

Read the repository instructions — prefer `AGENTS.md`; if absent, read `CLAUDE.md`. Read the full `## Git Workflow` (or equivalent) section before acting. Capture the test command and every applicable project-specific requirement, including pre-merge checks, merge or push rules, post-merge deployment or sync commands, and verification steps.

Treat those requirements as part of this workflow and run them at the stage the project specifies. If no such section exists, use the defaults below.

## Step 2: Resolve What to Merge

Resolve the exact PR or branch from the user's request and current repository evidence. If the target or merge mode is ambiguous, list the candidates and ask. Do not add a redundant confirmation when the user already authorized an exact target.

Two modes:

- **Local merge** — merge a feature branch into main locally
- **PR merge** — merge via `gh pr merge`

If already on main with no feature branch, inform the user and stop.

## Step 3: Verify Feature Candidate

Resolve the clean feature `HEAD` commit and tree. Reuse complete repository verification only when the evidence records the exact command and successful result after final code review and is bound to that same commit and tree. If the candidate changed, the evidence is missing, or the repository explicitly requires a fresh pre-merge run, run the configured test command or `pytest` by default.

If no automated tests exist, run the repository's validation or exercise the changed behavior when practical and report any verification gap.

Treat failures as evidence, not an automatic harness veto. Diagnose their relevance, fix in-scope regressions, and disclose unresolved failures before merging. Proceed only when the failure does not invalidate the change and the user's authorization covers accepting that evidence.

## Step 4: Merge

Do not rebase the feature branch unless the user explicitly requests it. Preserve the branch history through a merge.

### Local Merge
```bash
git checkout main
git pull --ff-only
git merge --no-ff <feature-branch>
```

### PR Merge
```bash
gh pr merge --merge
```

## Step 5: Test on Main

After merging, run the same test command on main.

If tests fail, report immediately and determine whether the merge introduced the failure. Do not push a known regression. For unrelated or pre-existing failures, disclose the evidence before deciding whether existing authorization covers the push.

## Step 6: Push

Push a local merge only when the user's request or repository workflow explicitly authorizes it. Otherwise report that local `main` is ahead.

```bash
git push origin main
```

## Step 7: Run Project-Specific Follow-up

Run every remaining requirement from the project's Git Workflow that the user has authorized, such as deployment, remote sync, smoke checks, or live verification. Ask before a consequential follow-up when the request did not already authorize it.

If a follow-up fails, preserve and report the evidence. Do not claim that deployment or verification succeeded.

## Step 8: Clean Up

Clean up only when the user's request or repository workflow authorizes it.

Delete the feature branch:

```bash
# Local branch
git branch -d <feature-branch>

# Remote branch — always verify it's deleted
git push origin --delete <feature-branch>
# (PR merge may auto-delete, but check and clean up if not)
```

Check for worktree:
```bash
git worktree list
```

If the feature branch had a worktree, remove it (only after confirming it belongs to the merged branch):
```bash
git worktree remove <worktree-path>
```

If that worktree was registered as a saved local Codex project for continuation tasks, remove the matching project registration after the worktree is removed. If project removal is unavailable, report the exact stale project path that the user must remove from the app; do not leave it unmentioned.

## Step 9: Close the Linked Issue

After the merge is pushed, close a linked GitHub issue only when the user's request or repository workflow authorizes issue closure.

Find the issue number from the branch name or the merged commit messages (e.g. `issue #106`, `fixes #106`, `closes #42`). If exactly one issue is referenced, close it with a comment pointing at the merge commit:

```bash
gh issue close <number> --comment "Resolved by <merge-commit-sha> on main."
```

If multiple distinct issues are referenced, close each. If none is referenced, skip this step. If the merge happened via `gh pr merge` and the PR body used a closing keyword (`Closes #N`), GitHub already closed the issue — verify with `gh issue view <number>` and only close manually if still open.

## Summary

| Step | Local Merge | PR Merge |
|------|-------------|----------|
| Verify branch | reuse exact evidence or test | reuse exact evidence or test |
| Merge | `git merge --no-ff` | `gh pr merge --merge` |
| Test main | yes | yes |
| Push main | when authorized | automatic with PR merge |
| Project follow-up | when authorized | when authorized |
| Delete local branch | when authorized | when authorized |
| Delete remote branch | when authorized | automatic if configured |
| Remove worktree | when authorized | when authorized |
| Remove worktree project registration | with authorized worktree cleanup | with authorized worktree cleanup |
| Close linked issue | when authorized | verify automatic closure before acting |
