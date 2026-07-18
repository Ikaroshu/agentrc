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
Choose the workflow based on scope:

- For small, clear, low-risk changes, implement and test directly.
- When intent, requirements, or design choices are unclear, recommend brainstorming. If the change is also large, cross-cutting, or high-risk, recommend continuing through planning and doc review.
- For large, cross-cutting, or high-risk changes whose requirements are already settled, recommend planning and doc review without requiring brainstorming first.
- For borderline changes, briefly give your recommendation and let the user choose.

Ask before invoking an optional workflow. When the user chooses planning, follow: **[brainstorm →] plan → doc-review → worktree → implement → code-review → merge.** The agent invokes each chosen skill when its stage is reached. During brainstorming, get approval on the design. After doc review findings are addressed, pause and ask the user for a go/no-go on the reviewed plan and spec before creating a worktree or starting implementation. After code review findings are addressed, pause again and ask the user for a final go/no-go before merging. Outside these required checkpoints, proceed without asking the user to invoke skills or reconfirm. Brainstorming may also be used alone for a small but ambiguous change; after the design is approved, implement and test directly.

1. **Brainstorm (optional)** — Use the `brainstorming` skill to resolve unclear requirements and design choices. It asks questions one at a time, compares approaches, and produces an approved design. It does not write the implementation plan.
2. **Plan** — Use the `planning` skill on `main`, in the main repo cwd, NOT a worktree. It turns settled requirements into an executable plan at `<project-root>/.plans/plans/`. Brainstorming may supply a spec at `<project-root>/.plans/specs/`. **Do NOT commit** plans or specs.
3. **Doc-review** — Invoke `adversarial-doc-review` on the plan/spec. It uses the local read-only OMP review profile and tiered OpenRouter models, shared by Claude and Codex. Address findings before coding.
4. **Worktree** — Create an isolated worktree under `<project-root>/.worktrees/` for the implementation. Skip for small changes when `main` is clean.
5. **Implement** — Use the `implement` skill: one fresh task-owner subagent per task, each accountable for choosing an appropriate implementation and testing sequence and providing real verification evidence, with a review checkpoint between tasks. Prefer test-first for bugs, behavior changes, and logic with a clear executable contract. Implementation-first is acceptable when it better fits the work, but the task owner must briefly explain the choice and still test or otherwise verify the result before completion.
6. **Code-review** — After a development phase and before merging, invoke the shared `code-review` skill. It uses the local read-only OMP review profile and tiered OpenRouter models. For each finding, **verify it's real before acting** (reviewers misread context and hit sandbox artifacts), then fix it or push back with specific reasoning — never silently skip, never blindly implement.
7. **Merge** — Use the `merge` skill.

- **Cap `adversarial-doc-review` and `code-review` at TWO invocations per session** (initial review plus at most one re-review). Do not run a third on your own initiative — if a third pass seems warranted, ask the user first.

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
