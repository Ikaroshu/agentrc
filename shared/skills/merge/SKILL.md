---
name: merge
description: Run Shu's merge workflow for a branch or pull request. Use when the user asks to merge, finish a branch, merge a PR, or clean up after merging. Always confirms the exact PR or branch, tests before and after merge, cleans up local and remote branches and worktrees, and closes the linked issue.
---

# Merge Workflow

Test, merge, test again, and clean up. Handles both local merges and PR merges.

**Announce at start:** "Running merge workflow."

## Step 1: Confirm What to Merge

**Always ask the user to confirm which PR or branch to merge.** Never auto-merge whatever branch happens to exist on the remote. List open PRs (`gh pr list`) and ask explicitly.

Two modes:

- **Local merge** — merge a feature branch into main locally
- **PR merge** — merge via `gh pr merge`

If already on main with no feature branch, inform the user and stop.

## Step 2: Test on Feature Branch

Run the project's test command (from `## Git Workflow` in the repo instructions — `AGENTS.md`, falling back to `CLAUDE.md` — or `pytest` by default).

**If no automated tests exist:** actually start the app, exercise the changed functionality, and verify it works end-to-end. If you can't fully verify (e.g., UI changes, auth flows), **ask the user to manually test before proceeding**. Do not skip testing just because there's no test suite.

**If tests fail, stop.** Do not proceed with merge.

## Step 3: Merge

### Local Merge
```bash
git checkout main
git pull --ff-only
git merge <feature-branch>
```

### PR Merge
```bash
gh pr merge --merge
```

## Step 4: Test on Main

After merging, run the same test command on main.

**If tests fail:** report immediately. Do NOT push. The user decides how to proceed.

## Step 5: Push

```bash
git push origin main
```

## Step 6: Clean Up

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

## Step 7: Close the Linked Issue

After the merge is pushed, close any GitHub issue the merged work resolves — do this automatically, without being asked.

Find the issue number from the branch name or the merged commit messages (e.g. `issue #106`, `fixes #106`, `closes #42`). If exactly one issue is referenced, close it with a comment pointing at the merge commit:

```bash
gh issue close <number> --comment "Resolved by <merge-commit-sha> on main."
```

If multiple distinct issues are referenced, close each. If none is referenced, skip this step. If the merge happened via `gh pr merge` and the PR body used a closing keyword (`Closes #N`), GitHub already closed the issue — verify with `gh issue view <number>` and only close manually if still open.

## Summary

| Step | Local Merge | PR Merge |
|------|-------------|----------|
| Test branch | yes | yes |
| Merge | `git merge` | `gh pr merge` |
| Test main | yes | yes |
| Push main | yes | automatic |
| Delete local branch | yes | yes |
| Delete remote branch | yes | automatic |
| Remove worktree | if exists | if exists |
| Close linked issue | yes | verify (auto if PR keyword) |
