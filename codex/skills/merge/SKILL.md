---
name: merge
description: Merge, finish, or clean up a branch or pull request through Shu's workflow by verifying the exact candidate and main, running authorized follow-ups, and cleaning up safely.
---

# Merge Workflow

Verify the candidate, merge locally or through a PR, verify main, run authorized follow-ups, and clean up. The implementation owner is the main agent for direct work or the implementer subagent for delegated work.

**Announce at start:** "Running merge workflow."

## Prepare

Read repository instructions, preferring `AGENTS.md` then `CLAUDE.md`, and the complete Git Workflow equivalent. Capture tests, pre-merge checks, merge/push rules, deployment or sync, and verification. These requirements run at their specified stage; otherwise use the defaults below.

Resolve the exact branch or PR and local-versus-PR mode from the request and repository. Ask only if ambiguous; do not reconfirm an authorized target. If already on main without a feature target, stop.

## Verify the candidate

Resolve clean feature `HEAD` and tree. Require the implementation owner's recorded settled verification evidence for the same commit and tree, recorded after the last code change and immediately before the accepted code review. Accept that recorded evidence without inspecting the implementation diff or rerunning its verification. If the evidence is absent or mismatched, stop and return the candidate to implementation and code review before a new merge-approval request; do not substitute a post-review test run. Run only checks that repository instructions explicitly assign to the merge stage.

Treat merge-stage check failures as evidence: return candidate-related technical diagnosis and repair to the same implementation owner, and do not merge a candidate whose settled verification or code-review acceptance is invalidated.

## Merge

Never rebase unless requested; preserve history with a merge.

```bash
# Local
git checkout main
git pull --ff-only
git merge --no-ff <feature-branch>
# PR
gh pr merge --merge
```

## Verify main

Run only checks that repository instructions explicitly assign after merge; do not rerun implementation verification merely to duplicate the accepted evidence. Stop on failure, return candidate-related technical diagnosis and repair to the same implementation owner, and never push a known regression; disclose unrelated or pre-existing failures before deciding whether authorization covers the push.

## Push

Push a local merge only when the request or repository workflow authorizes it; otherwise report that main is ahead.

```bash
git push origin main
```

## Follow up

Run every remaining authorized Git Workflow requirement, such as deployment, sync, smoke checks, or live verification. Ask before an unauthorized consequential follow-up. Preserve and report failures without claiming success.

## Clean up

Cleanup is part of an authorized merge and needs no separate approval. After merge, required verification, and applicable push succeed, remove the merged branch and clean owned worktree unless retention was requested. Stop if the worktree is dirty, the branch is not fully merged, or ownership is ambiguous.

Delete the feature branch:

```bash
git branch -d <feature-branch>
git push origin --delete <feature-branch>
git worktree list
git worktree remove <worktree-path>
```

Verify remote deletion when applicable. After removing a worktree, remove its saved local Codex project registration; if unavailable, report the exact stale project path.

## Close linked issues

After push, close linked issues only when authorized. Resolve them from branch and commit messages; close each distinct reference with the merge commit:

```bash
gh issue close <number> --comment "Resolved by <merge-commit-sha> on main."
```

Skip when none are referenced. For PR closing keywords, verify GitHub's automatic closure and close manually only if still open.
