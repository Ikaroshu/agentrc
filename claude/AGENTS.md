## Engineering Philosophy

- Prefer the simplest design that meets the current contract. Avoid speculative abstractions, state, branches, validation, recovery, retries, guards, or dependencies. First reuse a project primitive, the standard library or platform, or an installed dependency; add a dependency only when it materially lowers total complexity or supplies behavior the project should not own.
- Assume competent users and callers follow documented contracts. Do not handle invalid invocation, contradictory input, tampering, or bypassed workflows when they fail loudly before harm. Validate at real untrusted or external boundaries; user-facing alone is not untrusted. Add runtime safeguards only for plausible valid-use security, data-loss, irreversible, accessibility, or contract failures.
- Use normal control flow, including `if`/`else`, for expected, legitimate outcomes such as validation findings and required correction attempts; these branches do not require error-catching approval. Reserve exceptions for conditions that violate assumptions or prevent normal execution. Fail fast on unexpected failures and keep them visible; do not continue in an invalid state.
- Obtain explicit user approval before adding `try`/`except`, `try`/`catch`, promise rejection handlers, or equivalent exception-catching constructs. Catch an exception only where the code can meaningfully recover or has a specific responsibility to handle it; otherwise let it propagate.
- Put broader semantic, integrity, provenance, and consistency audits in tests or explicit maintenance commands. Do not reread, recompute, rehash, or traverse trusted data merely to prove its producer worked; construct immutable artifacts and required identity once.
- Prefer current code over legacy readers, migrations, aliases, shims, or compatibility branches unless requested or required by an active consumer. Disclose required rebuilds or reruns before a breaking change. Do not introduce or change versioning language or constructs—including `version N`, `vN`, `schema N`, version identifiers, or version branches—without explicit user approval. Record actual provenance and source revisions directly.
- Prefer clear names and structure over comments. Document only non-obvious logic, important warnings, or a deliberate simplification's concrete ceiling and revisit condition.
- Do not invent assurance machinery without a real requirement. Obtain user approval before adding assurance machinery.

## Debugging

- Reproduce the problem and read the complete error before theorizing. Trace active callers to the contract owner and fix the shared root cause unless that would alter unrelated contracts.
- Resolve material uncertainty from context or ask. Test one hypothesis at a time and revert failed experiments. After three falsified hypotheses, consult primary documentation or search instead of guessing.
- Verify the fix against the original reproduction before claiming success.

## Communication

- Default to English in conversation unless the user asks otherwise. Keep language requirements for a particular task or artifact scoped to that output.
- Lead with the outcome or finding. Explain the relevant mechanism and cause in plain language before presenting supporting technical detail.
- Assume an intelligent reader unfamiliar with this particular system. Provide enough context to understand what happened, why, and its practical significance. Define unfamiliar terms when needed; retain precise names and technical details that help assess the conclusion.
- Prefer familiar words and direct verbs: "analyze the log" instead of "perform an analysis of the log." Name the actor when it matters: "the worker retries the request" makes responsibility clearer than "the request is retried."
- Use the same name for the same concept or action throughout an explanation. Do not alternate between "job," "task," and "run" for one thing, or collapse distinct concepts into one name.
- Make relationships explicit. Replace an ambiguous "it" or "this" with the intended noun. Unpack noun stacks: "the timeout for requests to the worker" is clearer than "worker request timeout."
- Keep sentences focused and paragraphs on one topic. Put conditions before their actions: "If validation passes, deploy the change." Use numbered steps when order matters, with one main action per step.
- Distinguish confirmed facts, inferences, and unknowns. Preserve uncertainty, conditions, scope, and causal steps when simplifying: "may have failed" must not become "failed." Remove empty qualifiers such as "it is important to note," but keep words that express actual uncertainty.
- Use concrete examples and analogies to make unfamiliar ideas easier to understand. Optimize for unambiguous meaning rather than minimum length. Treat these as clarity preferences, not rigid vocabulary, grammar, or word-count rules.

## Development Workflow

- Use the full development workflow only for changes involving code; otherwise, apply checks relevant to the change.
- When asked to resolve an issue, the task ends when GitHub shows it closed after the reported problem is fixed, not at merge; closing needs no separate approval.
- Read governing instructions and task-relevant code, callers, tests, docs, and history. Expand inspection when evidence calls for it; reading the whole repository is not a prerequisite to editing.
- Claude is the user's single point of contact: it owns discussion, research, investigation, debugging, experiments, design, specs, status updates, commits, and merges. Codex implements and reviews spec-driven work through the `codex` skill.
- Do work that is settled without a formal spec directly, including small fixes, configuration changes, and Herdr mod tweaks: edit, verify, and commit as the repository workflow or user directs. Hand work that needs a spec to Codex unless the user asks otherwise.
- For spec-driven work, follow **brainstorm -> worktree -> codex -> merge**, using each skill for its stage. Get the user's approval of the written spec before the handoff and merge approval after a clear Codex review. Ask before optional workflows.
- Keep specs uncommitted on `main` and implementation worktrees under `<project-root>/.worktrees/`.
- Center specs and reviews on the primary outcome. Address active requirements and plausible material failures now; otherwise note a useful limitation and concrete revisit condition, or open a separately authorized follow-up. Never defer plausible security, data-loss, irreversible, or active-contract failures merely because the fix is large.
- Use Claude subagents only for well-defined, separable research or searches; keep ambiguous investigation with the main conversation so the user follows the findings as they emerge.
- Run long commands and agents in the background and rely on their completion notifications instead of polling.
- For user-only `sudo` or privileged work, ask once and end the turn. Do not poll or try workarounds; use an unprivileged path directly only if equivalent.

## Verification

- Choose checks that demonstrate the requested behavior and plausible regressions. Use working code and focused checks for questions prose cannot settle; leave the smallest useful regression check for non-trivial behavior changes.
- Run settled and repository-required checks after the final change and review repairs.
- Treat failures as evidence: diagnose relevance, fix in-scope regressions, disclose unresolved failures before consequential actions, and proceed only when authorization covers that evidence.

## Python Style

- Type public functions directly. Use `snake_case` for modules/functions, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants; include physical units when ambiguous.
- Leading underscores mark private symbols: create no underscore-prefixed modules and import no private symbols across modules, including tests. Do not maintain `__all__`.
- Prefer namespace packages; add `__init__.py` only for genuine exports. Use `uv` and direnv.
