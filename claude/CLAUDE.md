## Me
Shu (xx9liao@gmail.com)

## General Coding Style
- **Docstrings:** Prefer self-explanatory code (clear naming, simple structure) over comments. Add docstrings only to explain non-obvious logic, subtle gotchas, or important warnings.
- **No silent safety nets:** Don't silently swallow unexpected errors. Anything unexpected should warn or error — silent catches hide bugs.

## Debugging Guidelines
- Ask clarifying questions before suggesting fixes.
- Write short scripts to falsify/validate your assumption about the fix.
- Search online for solutions after 3 assumptions has been falsified.

## Superpowers Plugin Instruction
- Save plans to `<project-root>/.superpowers/plans/` and specs to `<project-root>/.superpowers/specs/` (NOT inside worktree directories — worktrees are ephemeral)
- DO NOT commit plans and specs
- After writing the spec and plan, invoke `/codex:adversarial-review` via the Skill tool on both files before starting implementation. Address findings before proceeding.

## PR & Merge Workflow
- **Always confirm which PR** before merging — never auto-merge whatever branch is found on remote. Ask the user to confirm.
- **Test thoroughly before merging** — actually run the app/tests and verify functionality works end-to-end. If automated tests aren't sufficient, ask the user to manually test before proceeding with merge.
- **Clean up remote branches** after a successful PR merge (if not auto-deleted by the PR merge itself).

## Pre-existing errors (lint, type check, tests)
- If pre-stage checks (ruff, pyright, pytest, etc.) fail on files I did NOT touch in this session, **STOP**. Do not silently classify them as "pre-existing and unrelated" and move on.
- Report the errors to the user and ask explicitly: "these are pre-existing failures in <files> — fix in this session, or commit around them?"
- Only proceed once the user answers. Never commit with known failing checks without confirmation, even if my own changes are clean.

## Python Coding Style
- **Type hints:** Add type hints on public functions; prefer direct type annotations over quoted
- **Naming conventions:**
  - `snake_case` for modules/functions
  - `PascalCase` for classes
  - `UPPER_SNAKE_CASE` for constants
- **Packages:** Prefer namespace packages; avoid `__init__.py` unless explicit symbol exports needed
- **Error handling:** Don't use `try/except` for normal control flow; catch exceptions only at clear integration boundaries
- **Environment:** 
  - Use `uv` for Python package management
  - Use direnv with .envrc for automatic venv activation

@RTK.md
