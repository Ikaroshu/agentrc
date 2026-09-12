---
name: commit
description: Validate and commit repository changes, run required post-commit actions, and push main or an authorized feature branch.
---

# Commit Workflow

Validate, commit, complete repository-required post-commit actions, then push `main` automatically or another branch when authorized.

## Prepare and verify

Read repository instructions (`AGENTS.md`, or `CLAUDE.md` when applicable), including the complete Git Workflow requirements for checks, hooks, deployment, sync, and push. Run prescribed checks; otherwise choose proportionate verification and report the gap. Reuse successful checks for the unchanged candidate unless a later-stage rerun is required. Diagnose failures and fix in-scope regressions before proceeding; disclose unresolved failures and require authorization covering that evidence.

## Commit

Review `git status` and `git diff`. Stage relevant files by name, never `git add -A` or `git add .`, preserving unrelated changes. Commit with a concise message in repository style.

Run hooks normally in their required environment on the first attempt. For a uv/direnv repository, use `direnv exec . env -u PYTHONPATH -u VIRTUAL_ENV uv run git commit ...`. After a hook failure, fix, restage, and create a new commit.

## Complete

Run repository-required post-commit actions in order. Invoking this workflow authorizes actions explicitly required for commit completion, not other external mutations.

Re-resolve the branch and inspect unpublished commits. If a push would publish unrelated commits, disclose them and ask. Otherwise push `origin main` automatically on `main`; on another branch, push only when the user or repository workflow authorizes it.
