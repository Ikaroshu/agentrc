## Engineering Philosophy

- Prefer the simplest design that meets the current contract. Avoid speculative abstractions, state, branches, validation, recovery, retries, guards, or dependencies. First reuse a project primitive, the standard library or platform, or an installed dependency; add a dependency only when it materially lowers total complexity or supplies behavior the project should not own.
- Assume competent users and callers follow documented contracts. Do not handle invalid invocation, contradictory input, tampering, or bypassed workflows when they fail loudly before harm. Validate at real untrusted or external boundaries; user-facing alone is not untrusted. Add runtime safeguards only for plausible valid-use security, data-loss, irreversible, accessibility, or contract failures.
- Do not add `try`/`except`, `try`/`catch`, promise rejection handlers, or equivalent constructs that intercept errors, including error-result branches that recover, translate, suppress, retry, or continue after failure. Let failures propagate directly. Obtain explicit user approval before implementing any such error-catching construct.
- Put broader semantic, integrity, provenance, and consistency audits in tests or explicit maintenance commands. Do not reread, recompute, rehash, or traverse trusted data merely to prove its producer worked; construct immutable artifacts and required identity once.
- Prefer current code over legacy readers, migrations, aliases, shims, or compatibility branches unless requested or required by an active consumer. Disclose required rebuilds or reruns before a breaking change. Do not introduce or change versioning language or constructs—including `version N`, `vN`, `schema N`, version identifiers, or version branches—without explicit user approval. Record actual provenance and source revisions directly.
- Prefer clear names and structure over comments. Document only non-obvious logic, important warnings, or a deliberate simplification's concrete ceiling and revisit condition.
- Do not invent assurance machinery without a real requirement. Obtain user approval before adding assurance machinery.

## Debugging

- Reproduce the problem and read the complete error before theorizing. Trace active callers to the contract owner and fix the shared root cause unless that would alter unrelated contracts.
- Resolve material uncertainty from context or ask. Test one hypothesis at a time and revert failed experiments. After three falsified hypotheses, consult primary documentation or search instead of guessing.
- Verify the fix against the original reproduction before claiming success.

## Communication

- Lead with the outcome or finding. Explain the relevant mechanism and cause in plain language before presenting supporting technical detail.
- Assume an intelligent reader unfamiliar with this particular system. Provide enough context to understand what happened, why, and its practical significance. Define unfamiliar terms when needed; retain precise names and technical details that help assess the conclusion.
- Distinguish confirmed facts, inferences, and unknowns. Be concise without skipping causal steps. Use examples or analogies only when they clarify the mechanism.

## Development Workflow

- Read governing instructions and task-relevant code, callers, tests, docs, and history. Expand inspection when evidence calls for it; reading the whole repository is not a prerequisite to editing.
- Follow **[brainstorm ->] worktree -> implement -> code-review -> merge**, using each skill for its stage. Use brainstorming for material uncertainty or a durable spec. Approval of a settled contract suffices without a spec; with a spec, get implementation approval after document review. Get merge approval after clear code review. Ask before optional workflows; add no reconfirmation gates for authorized in-scope work, verification, or repairs.
- Match each delegation and follow-up to the role’s defined job. Keep ordinary questions, explanations, clarifications, status updates, standalone commit requests, and merge execution with the main agent. Use implementers for assigned implementation and its verification and repairs; use reviewers for assigned code or document reviews and clarification of their own findings. An existing agent or its prior context is not a reason to send it unrelated work.
- Before choosing an implementation owner, identify the smallest likely change and how to verify it. Keep simple work with straightforward design and verification with the main agent; use the implementer for substantive or complex work. Shared code, potential impact, file count, a settled design, or absence of a spec alone does not determine complexity.
- Keep specs uncommitted on `main` and implementation worktrees under `<project-root>/.worktrees/`. Request scoped escalation on the first Git metadata write when the worktree's resolved Git directory is outside writable roots.
- Center specs and reviews on the primary outcome. Address active requirements and plausible material failures now; otherwise note a useful limitation and concrete revisit condition, or open a separately authorized follow-up. Never defer plausible security, data-loss, irreversible, or active-contract failures merely because the fix is large.
- The implementation owner integrates assigned changes, verifies them, commits the implementation candidate, and completes review repairs. This ownership ends at delivery of a clean committed candidate and does not include merging it. During delegated implementation and its review, the main agent records the owner’s evidence and limits candidate inspection to read-only identity and status checks; native reviewers own technical review. These limits do not transfer ownership of user communication or later commit and merge workflows to subagents.
- Each document or code review unit gets at most two completed passes; repairs, replacements, and follow-ups do not reset the count. The review skills own clarification, repair scope, and stopping rules. Dispatch implementation review only for a clean immutable candidate with completed verification and no unresolved work. Acceptance is the last technical gate: ask for merge approval immediately. Later code or configuration changes or failed checks invalidate acceptance.
- Treat agents and long commands as event-driven. Wait for the requested owner, reviewer, or process; handle unrelated events and resume. Use the longest supported empty terminal wait. Do not poll or narrate unchanged state; check separately only after abnormal duration or a concrete signal.
- For user-only `sudo` or privileged work, ask once and end the turn. Do not poll or try workarounds; use an unprivileged path directly only if equivalent.

## Verification

- Choose checks that demonstrate the requested behavior and plausible regressions. Use working code and focused checks for questions prose cannot settle; leave the smallest useful regression check for non-trivial behavior changes.
- Run settled and repository-required checks after the final change and review repairs. Once they pass, broaden or repeat only for new changes, failures, unresolved concerns, or an explicitly required later-stage check.
- Treat failures as evidence: diagnose relevance, fix in-scope regressions, disclose unresolved failures before consequential actions, and proceed only when authorization covers that evidence.

## Python Style

- Type public functions directly. Use `snake_case` for modules/functions, `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants; include physical units when ambiguous.
- Leading underscores mark private symbols: create no underscore-prefixed modules and import no private symbols across modules, including tests. Do not maintain `__all__`.
- Prefer namespace packages; add `__init__.py` only for genuine exports. Use `uv` and direnv.
