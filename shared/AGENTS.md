## General Coding Style
- **Comments & docstrings:** Prefer self-explanatory code (clear naming, simple structure) over comments. Add docstrings only to explain non-obvious logic, subtle gotchas, or important warnings.
- **Fail out loud:** Don't add defensive code — error handling, input validation, fallbacks, or "just in case" guards for conditions that shouldn't happen given the surrounding contract. Don't silently swallow unexpected errors. Don't use `try/except` (or equivalent) for normal control flow. These turn loud failures into silent ones and hide real bugs. Let errors propagate so the actual cause is visible. Validate or catch only at true system boundaries (untrusted input, external APIs, user-facing entry points).

## Debugging Guidelines
- **Reproduce first** — get a reliable repro and read the full error before theorizing. No repro yet means keep gathering evidence, not guessing.
- Ask clarifying questions before suggesting fixes.
- Write short scripts to falsify/validate your assumption about the cause; fix the root cause, not the symptom.
- **One change at a time** — if a fix doesn't work, revert it before trying the next. Don't stack speculative patches.
- Search online for solutions after 3 assumptions have been falsified.
- **Verify against the original repro** before claiming it's fixed.

## Development Workflow
For non-trivial features or changes, follow: **brainstorm → plan → doc-review → worktree → implement → code-review → merge.** The agent invokes each skill when its stage is reached. After doc review findings are addressed, pause and ask the user for a final go/no-go on the reviewed plan and spec before creating a worktree or starting implementation. Once the user gives the go-ahead, proceed through the remaining stages without asking them to invoke skills or reconfirm.

1. **Brainstorm + plan** — Use the `brainstorming` skill (on `main`, in the main repo cwd, NOT a worktree). It asks questions one at a time, then writes a plan to `<project-root>/.plans/plans/` and, for ambiguous work, a spec to `<project-root>/.plans/specs/`. **Do NOT commit** plans or specs.
2. **Doc-review** — Invoke `adversarial-doc-review` on the plan/spec. Claude shells out to `codex exec`; Codex shells out to `claude -p`. Address findings before coding.
3. **Worktree** — Create an isolated worktree under `<project-root>/.worktrees/` for the implementation. Skip for small changes when `main` is clean.
4. **Implement** — Use the `implement` skill: one fresh subagent per task, each running a full TDD RED→GREEN→verify cycle, with a review checkpoint between tasks.
5. **Code-review** — After a development phase and before merging, run the cross-agent diff review: `codex-code-review` (Claude) or `claude-code-review` (Codex). For each finding, **verify it's real before acting** (reviewers misread context and hit sandbox artifacts), then fix it or push back with specific reasoning — never silently skip, never blindly implement.
6. **Merge** — Use the `merge` skill.

- **Cap `adversarial-doc-review` and the cross-agent code review at TWO invocations per session** (initial review plus at most one re-review). Do not run a third on your own initiative — if a third pass seems warranted, ask the user first.
- Trivial changes may skip the ceremony entirely. Use judgment about scope.

## GitHub Issues
- Issue bodies describe the problem and context only — no proposed fixes, suggested approaches, design sketches, or acceptance criteria. The author often doesn't fully understand the problem; prescribing a solution biases whoever picks it up later.

## Pre-existing Errors (lint, type check, tests)
- If pre-stage checks (ruff, pyright, pytest, etc.) fail on files I did NOT touch in this session, **STOP**. Do not silently classify them as "pre-existing and unrelated" and move on.
- Report the errors to the user and ask explicitly: "these are pre-existing failures in <files> — fix in this session, or commit around them?"
- Only proceed once the user answers. Never commit with known failing checks without confirmation, even if my own changes are clean.

## Python Coding Style
- **Type hints:** Add type hints on public functions; prefer direct type annotations over quoted
- **Naming conventions:**
  - `snake_case` for modules/functions
  - `PascalCase` for classes
  - `UPPER_SNAKE_CASE` for constants
  - No underscore-prefixed module files (`_xxx.py`). Module identity is conveyed by package structure, not filename leading underscores — name the module for what it holds (e.g. `decision_bound.py`, not `_decision_bound.py`).
  - **Symbol privacy is a house-rule convention: a leading underscore on a name (`_helper`, `_CACHE`) marks it private; no leading underscore means public API.** Do NOT maintain `__all__` — the underscore convention is the only privacy signal. A symbol consumed by another module must be public (no underscore); never import an underscore-prefixed name across module boundaries, including from tests.
- **Packages:** Prefer namespace packages; avoid `__init__.py` unless a package genuinely needs to re-export symbols at the package level (still no `__all__` — rely on the underscore convention)
- **Environment:**
  - Use `uv` for Python package management
  - Use direnv with .envrc for automatic venv activation
