# Commit Workflow

Run tests, commit, and push. Adapt behavior based on the project's CLAUDE.md.

**Announce at start:** "Running commit workflow."

## Step 1: Read Project Config

Look for `## Git Workflow` in the project's CLAUDE.md for these fields:
- **Pre-stage checks** — lint/type-check commands to run before staging (default: none)
- **Commit tests** — test command to run before commit (default: `pytest`)
- **Pre-commit** — whether pre-commit hooks are enforced (default: no)

If no `## Git Workflow` section exists, use defaults.

## Step 2: Run Pre-stage Checks

Run the configured pre-stage check commands (e.g., `ruff check --fix`, `pyright`). **If type checking fails, stop.** Fix lint issues automatically where possible, but do not proceed if errors remain.

## Step 3: Run Tests

Run the configured test command. **If tests fail, stop.** Do not proceed to commit.

## Step 4: Stage and Commit

1. Run `git status` and `git diff` to review changes
2. Stage relevant files by name (never `git add -A` or `git add .`)
3. Craft a concise commit message following the repo's existing style
4. Commit (pre-commit hooks will run automatically if configured)
5. If pre-commit fails, fix issues, re-stage, and create a NEW commit

## Step 5: Push

Push to the current branch:

```bash
git push origin $(git branch --show-current)
```

## Defaults Summary

| Setting | Serious project | Casual project |
|---------|----------------|----------------|
| Tests | from CLAUDE.md | `pytest` |
| Pre-commit | yes | no |
| Push | yes | yes |
