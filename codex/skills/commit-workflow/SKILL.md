---
name: commit-workflow
description: Run Shu's commit workflow for a repository. Use when the user asks to commit changes, run the commit workflow, or prepare a tested commit and push. Reads repo instructions for checks, runs validation before staging, stages files explicitly, commits with an appropriate message, and pushes the current branch.
---

# Commit Workflow

Announce: "Running commit workflow."

## Steps

1. Read the repository instructions.
   - Prefer `AGENTS.md`.
   - If this is a Claude-only repository with no `AGENTS.md`, read `CLAUDE.md`.
   - Look for `Git Workflow` or equivalent sections that define pre-stage checks, commit tests, pre-commit behavior, or push policy.

2. Run pre-stage checks.
   - Use the configured lint/type/test checks when present.
   - If no checks are configured, infer the smallest reasonable validation command from the repo.
   - If checks fail in files not touched in this session, stop and ask the user whether to fix them or commit around them.

3. Run commit tests.
   - Use the configured test command when present.
   - If no automated tests exist, run the repo's required validation gate or clearly report the gap.
   - Do not commit with known failing checks unless the user explicitly confirms.

4. Review and stage.
   - Run `git status` and inspect the relevant diff.
   - Stage files by explicit path. Do not use `git add -A` or `git add .`.
   - Preserve unrelated user changes.

5. Commit and push.
   - Write a concise message matching the repo's existing style.
   - Commit.
   - Push the current branch unless repo instructions or the user say otherwise.
