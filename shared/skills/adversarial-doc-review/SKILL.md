---
name: adversarial-doc-review
description: Run a Codex-backed adversarial review of a spec and/or implementation plan before implementation. Routes non-hard reviews to GPT-5.6 Sol at high effort and hard reviews to GPT-5.6 Sol at max effort, then returns findings inline for verification.
---

# Adversarial Doc Review

Use a nested, read-only Codex CLI session as a neutral third-party reviewer. Keep the reviewer's normal Codex tools, MCP servers, plugins, and repository context available; disable only the two workflow review skills in the nested session to prevent recursive review invocation.

## Prerequisites

- Require `codex` on `PATH` with working authentication.
- Run from the main repository cwd on the main branch, not from a worktree.

## Arguments

- `--spec <path>`: optional spec path.
- `--plan <path>`: optional plan path.
- `--focus <text>`: optional review emphasis.
- `--difficulty <non-hard|hard>`: optional explicit tier override.

Require at least one of `--spec` or `--plan`. Resolve every supplied document and both shared review `SKILL.md` files to absolute paths. Validate document paths as regular files; never auto-discover substitutes.

## Select the review tier

Honor an explicit `--difficulty`. Otherwise classify the supplied documents:

- **Non-hard / high effort**: localized or familiar work whose contracts and blast radius remain bounded, including ordinary multi-file changes.
- **Hard / max effort**: architecture or cross-system work; public APIs or schemas; migrations; concurrency; security; data-loss risk; high blast radius; or substantial ambiguity.

Classify as hard when any hard signal materially affects the design. Before invoking Codex, tell the user the selected tier and one-sentence rationale, then proceed immediately unless the user objects or supplied an override.

Use this exact mapping:

- non-hard: `gpt-5.6-sol`, `high`
- hard: `gpt-5.6-sol`, `max`

## Workflow

1. Render the prompt below with the supplied paths, optional focus, and selected tier.
2. Resolve the absolute paths of this skill and the sibling `code-review/SKILL.md`. Render them into the `skills.config` override so the nested Codex session cannot invoke either workflow review skill recursively.
3. Invoke Codex directly with the fully rendered prompt as one literal argument, substituting only the effort, the two skill paths, and the prompt:

   ```bash
   codex exec \
     --ephemeral \
     --model gpt-5.6-sol \
     --config 'model_reasoning_effort="{{EFFORT}}"' \
     --sandbox read-only \
     --color never \
     --config 'skills.config=[{path="{{DOC_SKILL_PATH}}",enabled=false},{path="{{CODE_SKILL_PATH}}",enabled=false}]' \
     '<fully rendered prompt>'
   ```

   Keep this argument order. Do not add `--ignore-user-config`, `--ignore-rules`, tool restrictions, MCP restrictions, shell wrappers, redirects, or backgrounding. The nested reviewer should inherit the normal Codex tool surface and local configuration while remaining filesystem read-only.

   When the caller is Codex, run with `sandbox_permissions="require_escalated"` and the justification: "Run the user-authorized nested read-only Codex document review?" The managed `codex-review.rules` rule records this exact read-only command prefix. Other callers should use their normal mechanism for running the command.

4. Start with a 30-second yield. If the process remains active, poll every 60 seconds until it exits. Do not treat elapsed time or a quiet interval as a hang, impose an arbitrary timeout, interrupt it, inspect its PID, or launch parallel status checks. Give the user brief progress updates while waiting.
5. Relay the verdict and findings. Verify each finding against the documents and repository context before editing. Classify it as confirmed, rejected with specific reasoning, or needing clarification. Never blindly implement or silently skip feedback.

## Prompt template

```text
You are the inner reviewer process for an adversarial design-document review.
Review tier: {{TIER}}. Perform the review directly. Do not invoke any review
skill or launch another Codex, Claude, or OMP process.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read every supplied file in full. Use your available read-only tools and
repository context where useful. Do not edit files.

{{FOCUS_BLOCK}}

Evaluate, in order:
1. Correctness and completeness: gaps, contradictions, unstated assumptions,
   and ignored edge cases.
2. Risk and blast radius: data loss, security, migrations, partial failure,
   reversibility, concurrency, and external contracts.
3. Design and alternatives: unnecessary complexity, premature abstraction,
   or a simpler viable approach.
4. Testability: exact verification, missing tests, and untestable claims.
5. Process and scope: scope creep or requirements silently dropped.

Output these exact sections:

## Verdict
APPROVE, APPROVE WITH CHANGES, or REWORK, followed by one sentence explaining why.

## Blocking findings
Numbered findings with file and line or section, problem, impact, and minimum fix. Write "None." if empty.

## Non-blocking suggestions
Numbered suggestions in the same form. Write "None." if empty.

## Questions for the author
Numbered questions required for approval. Write "None." if empty.

Be specific, do not flatter or restate the documents, and do not manufacture findings.
```

Omit absent file lines and the focus block instead of leaving placeholders.

## Failure handling

- Missing input: stop and report the exact path.
- Missing Codex CLI or authentication: stop and report the missing prerequisite without exposing credentials.
- Nonzero Codex exit: report the exit status and returned error; diagnose before retrying.
- Long run: keep polling until exit, a concrete hard error, impossible progress, or a user request to stop.
- No findings: spot-check the documents yourself before continuing.
