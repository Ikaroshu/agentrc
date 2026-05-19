---
name: merge-workflow
description: Run Shu's merge workflow for a branch or pull request. Use when the user asks to merge, finish a branch, merge a PR, or clean up after merging. Always confirms the exact PR or branch, tests before and after merge, and cleans up local and remote branches when appropriate.
---

# Merge Workflow

Announce: "Running merge workflow."

## Rules

- Always confirm the exact PR or branch before merging.
- Never auto-merge whatever branch happens to be on the remote.
- Test thoroughly before merging.
- If automated tests are insufficient, ask the user to manually verify the affected behavior before proceeding.
- Clean up local and remote branches after a successful merge when appropriate.

## Steps

1. Confirm what to merge.
   - Identify the current branch and any relevant PR.
   - Ask the user to confirm the exact target before running a merge command.

2. Test before merging.
   - Run the repo's configured checks or the smallest reliable validation gate.
   - If checks fail in files not touched in this session, stop and ask whether to fix them or merge around them.

3. Merge.
   - For local merges, update the base branch first, then merge the confirmed feature branch.
   - For PR merges, use the repository's preferred PR merge command or connector flow.

4. Test after merging.
   - Run the same validation on the target branch.
   - If validation fails after merge, report it and stop before pushing further cleanup.

5. Clean up.
   - Delete the merged local branch.
   - Verify whether the remote branch still exists and delete it if needed.
   - Remove any associated worktree only after confirming it belongs to the merged branch.
