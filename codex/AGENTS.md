## Engineering Philosophy

- Prefer the simplest design that meets the current contract. Avoid speculative abstractions, state, branches, validation, recovery, retries, guards, or dependencies. First reuse a project primitive, the standard library or platform, or an installed dependency; add a dependency only when it materially lowers total complexity or supplies behavior the project should not own.
- Assume competent users and callers follow documented contracts. Do not handle invalid invocation, contradictory input, tampering, or bypassed workflows when they fail loudly before harm. Validate at real untrusted or external boundaries; user-facing alone is not untrusted. Add runtime safeguards only for plausible valid-use security, data-loss, irreversible, accessibility, or contract failures.
- Do not add `try`/`except`, `try`/`catch`, promise rejection handlers, or equivalent constructs that intercept errors, including error-result branches that recover, translate, suppress, retry, or continue after failure. Let failures propagate directly. Obtain explicit user approval before implementing any such error-catching construct.
- Put broader semantic, integrity, provenance, and consistency audits in tests or explicit maintenance commands. Do not reread, recompute, rehash, or traverse trusted data merely to prove its producer worked; construct immutable artifacts and required identity once.
- Prefer current code over legacy readers, migrations, aliases, shims, or compatibility branches unless requested or required by an active consumer. Disclose required rebuilds or reruns before a breaking change. Use versions only for active generic protocols or meaningful provider versions; record actual provenance and source revisions directly.
- Prefer clear names and structure over comments. Document only non-obvious logic, important warnings, or a deliberate simplification's concrete ceiling and revisit condition.

## Debugging

- Reproduce the problem and read the complete error before theorizing. Trace active callers to the contract owner and fix the shared root cause unless that would alter unrelated contracts.
- Resolve material uncertainty from context or ask. Test one hypothesis at a time and revert failed experiments. After three falsified hypotheses, consult primary documentation or search instead of guessing.
- Verify the fix against the original reproduction before claiming success.

## Communication

- After exploration, issue triage, or debugging, concisely explain the relevant infrastructure and root cause in beginner-friendly language. Keep the key technical facts and clearly separate what is proven, inferred, and still unknown.

## Development Workflow

- Implement clear, low-complexity changes directly and scale verification and review to impact. Use brainstorming only when consequential uncertainty needs user input; use planning and document review only when settled complexity warrants phases. Ask before optional workflows.
- Center plans and reviews on the primary outcome. Handle an edge case now only for an active requirement or plausible material failure worth its cost; otherwise note the limitation and concrete revisit condition briefly or, when separately authorized, open a follow-up issue. Never defer plausible security, data-loss, irreversible, or active-contract failures merely because the fix is large.
- After one complete review and resolution of required findings, advance. Rereview only code-changing repairs or unresolved blockers; use working code and focused checks for questions prose cannot settle. For non-trivial behavior changes, leave the smallest focused regression check and scale surrounding verification to risk.
- Treat agents and long commands as event-driven. Wait for the requested owner, reviewer, or process; handle unrelated events and resume. Use the longest supported empty terminal wait. Do not poll or narrate unchanged state; check separately only after abnormal duration or a concrete signal.
- For commands known in advance to be long-running or high-output, including noisy test suites, lazily spawn at most one `command_runner` with `fork_turns="none"` per session and reuse its canonical target through `followup_task`, one command at a time. Keep quick, interactive, and live-judgment commands direct. Supply the exact command with all environment setup in its command string, plus its cwd, supported authorization or sandbox parameters, and required terminal evidence. Wait passively for its result without command-status queries, partial-transcript inspection, main-thread terminal polling, or child-output relay. A platform-required bounded wait or commentary event is not completion evidence; resume event-driven waiting, then verify the returned exit evidence before continuing.
- When a task needs user-only `sudo` or other privileged work, ask once and end the turn. Do not poll or try workarounds; take an unprivileged path directly only if it is equivalent.
- When chosen, follow **[brainstorm ->] plan -> doc-review -> worktree -> implement -> code-review -> merge**; the agent invokes each skill and lets it own its stage. Get design approval during brainstorming, implementation approval after doc review, and merge approval after final code review. Add no other reconfirmation gates.
- Keep plans and specs uncommitted on `main`; put planned implementation worktrees under `<project-root>/.worktrees/`. When a worktree's resolved Git directory is outside the writable roots, request scoped escalation on the first Git metadata write.

## GitHub Issues

- Unless asked otherwise, issue bodies contain only the problem and relevant context, not solutions or acceptance criteria.

## Check Failures

- Treat checks as evidence, not harness vetoes. Diagnose relevance, fix in-scope regressions, disclose unresolved failures before consequential actions, and proceed only when authorization covers that evidence.

## Python Style

- Type public functions directly. Use `snake_case` for modules/functions, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants; include physical units when ambiguous.
- Leading underscores mark private symbols: create no underscore-prefixed modules and import no private symbols across modules, including tests. Do not maintain `__all__`.
- Prefer namespace packages; add `__init__.py` only for genuine exports. Use `uv` and direnv.
