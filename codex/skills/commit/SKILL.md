---
name: commit
description: Run Shu's repository commit workflow to validate, stage explicitly, commit, complete required post-commit actions, and push main automatically or another branch when authorized.
---

# Commit Workflow

Validate, commit, complete repository-required post-commit actions, then push `main` automatically or another branch when authorized.

**Announce at start:** "Running commit workflow."

## Workflow

1. Read repository instructions, preferring `AGENTS.md` then `CLAUDE.md`, and the complete Git Workflow equivalent. Capture:

   - pre-stage checks (default none);
   - commit tests (default `pytest`);
   - enforced pre-commit hooks (default no); and
   - required post-commit deployment, sync, or verification (default none).

2. Run configured pre-stage checks and tests. If no tests exist, run repository validation or report the gap. Treat failures as evidence: diagnose relevance, fix in-scope regressions, disclose unresolved failures, and proceed only when authorization covers that evidence.

3. Review `git status` and `git diff`; stage relevant files by name, never `git add -A` or `git add .`, and preserve unrelated changes. Write a concise message in repository style and commit. Hooks run normally; after a hook failure, fix, restage, and create a new commit.

4. Run required post-commit actions in order. Invoking this workflow authorizes actions the repository explicitly requires for commit completion; infer no other external mutation.

5. Re-resolve the branch and inspect unpublished commits. If a push would publish unrelated commits, disclose them and ask. Otherwise push `origin main` automatically on `main`; on another branch, push only when the user or repository workflow authorizes it:

   ```bash
   git push origin $(git branch --show-current)
   ```
