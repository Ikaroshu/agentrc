---
name: adversarial-doc-review
description: Run a Codex-backed adversarial review of a spec and/or implementation plan before implementation. Routes non-hard reviews to GPT-5.6 Sol at xhigh effort and hard reviews to GPT-5.6 Sol at max effort, then returns findings inline for verification.
---

# Adversarial Doc Review

Use a nested, read-only Codex CLI session as a neutral third-party reviewer. Keep the reviewer's normal Codex tools, MCP servers, plugins, and repository context available; disable only the two workflow review skills in the nested session to prevent recursive review invocation.

## Prerequisites

- Require `agentrc-codex-doc-review` on `PATH`; the agentrc installer provides it.
- Require `codex` and `jq` on `PATH` with working Codex authentication.
- Run from the main repository cwd on the main branch, not from a worktree.

## Arguments

- `--spec <path>`: optional spec path.
- `--plan <path>`: optional plan path.
- `--focus <text>`: optional concern to emphasize without narrowing the review.
- `--difficulty <non-hard|hard>`: optional explicit tier override.

Require at least one of `--spec` or `--plan`. Resolve every supplied document and both shared review `SKILL.md` files to absolute paths. Validate document paths as regular files; never auto-discover substitutes.

If focus is supplied, prefer to keep the distilled emphasis within 80 words. Exceed that only when necessary to preserve materially distinct concerns, and briefly justify the extra detail. Do not pass scope exclusions, required conclusions, or instructions to omit review dimensions.

## Select the review tier

Honor an explicit `--difficulty`. Otherwise classify the supplied documents:

- **Non-hard / xhigh effort**: the design is straightforward, sufficiently specified, and follows established patterns with bounded interactions, including ordinary multi-file work and routine changes involving APIs, schemas, migrations, concurrency, or security.
- **Hard / max effort**: the review requires deeper reasoning because of interacting systems or contracts, difficult-to-reverse consequences, novel concurrency or security concerns, broad blast radius, or substantial unresolved ambiguity.

Assess overall review difficulty rather than document length or the presence of a category keyword. No individual category automatically makes a review hard; it must materially and non-routinely complicate the reasoning. A short plan may still be hard when that condition holds, while a straightforward plan remains non-hard even if it mentions one of these areas. Before invoking Codex, tell the user the selected tier and one-sentence rationale, then proceed immediately unless the user objects or supplied an override.

Use this exact mapping:

- non-hard: `gpt-5.6-sol`, `xhigh`
- hard: `gpt-5.6-sol`, `max`

## Workflow

1. Render the prompt below with the supplied paths and optional distilled focus.
2. Resolve this skill's absolute `SKILL.md` path so the nested Codex session cannot invoke the document-review workflow recursively.
3. Invoke the managed review runner. Substitute only the effort, skill path, and prompt:

   ```bash
   agentrc-codex-doc-review \
     "{{EFFORT}}" \
     "{{DOC_SKILL_PATH}}" \
     '<fully rendered prompt>'
   ```

   Keep this argument order and do not reconstruct or extend the underlying `codex exec` pipeline. Invoke the runner directly without an `env` or `PATH` wrapper; on macOS it selects the ChatGPT app-bundled Codex when the `PATH` binary lacks its required sibling host, preserving the managed permission-rule match. The runner fixes the model and read-only sandbox, disables recursive review skills, closes stdin, suppresses trace diagnostics, discards intermediate JSONL events, emits only the final agent message on stdout plus one short status heartbeat on stderr every 15 minutes, and preserves failures. The nested reviewer inherits the normal Codex tool surface and local configuration.

   When the caller is Codex, run with `sandbox_permissions="require_escalated"` and the justification: "Run the user-authorized nested read-only Codex document review?" The managed `codex-review.rules` rule records this exact read-only command prefix. Other callers should use their normal mechanism for running the command.

4. Treat the review as a long-running synchronous process and wait passively until it exits. The runner emits a one-line heartbeat every 15 minutes; let that be the only progress update and do not duplicate it with commentary or manual status checks. Tool-level polling may be necessary to keep the session attached; perform it silently with the longest practical wait. Notify the user directly only on completion, a concrete failure or blocker, a missing heartbeat for 30 minutes, or a user status request. Silence before the first heartbeat is expected; do not interrupt, inspect partial output, or launch parallel checks merely because it is quiet.
5. Relay the verdict and findings. Verify each finding against the documents and repository context before editing. Classify it as confirmed, rejected with specific reasoning, or needing clarification. Never blindly implement or silently skip feedback.

## Prompt template

```text
You are the inner reviewer process for an adversarial design-document review.
Perform the review directly. Do not invoke any review skill or launch another
Codex, Claude, or OMP process.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read every supplied file in full. Use your available read-only tools and
repository context where useful. Do not edit files.

Additional emphasis only; this does not narrow the review or suppress findings:
{{FOCUS_EMPHASIS}}

Evaluate, in order:
1. Problem validity and proportionality: whether the motivating problem is
   supported by realistic scenarios or evidence and is worth solving now.
   Distinguish likely real-world cases from speculative or extremely rare edge
   cases. Challenge designs whose complexity, maintenance burden, or risk
   outweighs the expected benefit, and identify when documentation, an
   operational workaround, or accepting the limitation would be preferable.
2. Correctness and completeness: gaps, contradictions, unstated assumptions,
   and ignored edge cases.
3. Risk and blast radius: data loss, security, migrations, partial failure,
   reversibility, concurrency, and external contracts.
4. Design and alternatives: unnecessary complexity, premature abstraction,
   or a simpler viable approach.
5. Testability: exact verification, missing tests, and untestable claims.
6. Process and scope: scope creep or requirements silently dropped.

Output these exact sections:

## Verdict
APPROVE, APPROVE WITH CHANGES, or REWORK, followed by a concise rationale
proportional to the verdict. For REWORK based on problem validity or
proportionality, explain the real-world evidence or likelihood gap, why the
design cost outweighs the expected benefit, and which simpler disposition
should be considered.

## Blocking findings
Numbered findings with file and line or section, problem, impact, and minimum fix. Write "None." if empty.

## Non-blocking suggestions
Numbered suggestions in the same form. Write "None." if empty.

## Questions for the author
Numbered questions required for approval. Write "None." if empty.

Be specific, do not flatter or restate the documents, and do not manufacture findings.
```

Omit absent file lines and the additional-emphasis lines instead of leaving placeholders.

## Failure handling

- Missing input: stop and report the exact path.
- Missing Codex CLI or authentication: stop and report the missing prerequisite without exposing credentials.
- Nonzero Codex exit: report the exit status and returned error; diagnose before retrying.
- Long run: use the runner heartbeat as the liveness guard and keep waiting silently until exit. React only to completion, a concrete hard error, a missing heartbeat for 30 minutes, impossible progress, or a user request.
- No findings: spot-check the documents yourself before continuing.
