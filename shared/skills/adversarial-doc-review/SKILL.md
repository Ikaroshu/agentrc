---
name: adversarial-doc-review
description: Run a Codex-backed adversarial review of a spec and/or implementation plan before implementation. Routes non-hard reviews to GPT-5.6 Sol at xhigh effort and hard reviews to GPT-5.6 Sol at max effort, then returns findings inline for verification.
---

# Adversarial Doc Review

Use an independent, read-only Codex reviewer. In a capable Codex runtime, use the configured `doc_reviewer` subagent. Claude, other harnesses, and Codex runtimes that do not expose that named role before the review starts use the managed CLI runner. Both transports share the same tier, prompt, output contract, finding-verification path, and logical-workflow turn counter.

## Prerequisites

- Run from the main repository cwd on the main branch, not from a worktree.
- For native review, require the collaboration tool to expose the exact configured `doc_reviewer` role and require the current parent local sandbox to be provably `read-only` before every initial or follow-up turn. A role default, an instruction-only prohibition, or an unknown effective sandbox is not proof.
- For managed review, require `agentrc-codex-doc-review`, `codex`, and `jq` on `PATH` with working Codex authentication. The agentrc installer provides the runner.

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
2. Select one transport before the logical workflow starts:
   - A Codex caller whose collaboration schema exposes the configured named role uses the native lifecycle below. Do not infer role availability from generic delegation support and never substitute a generic agent type.
   - Claude and other harnesses use the managed runner. A Codex caller also uses it when the configured role is not exposed before native start; announce this capability fallback briefly.
   - If a capable Codex caller has a writable or unknown parent local sandbox, stop before dispatch and ask the user to select read-only permission for the review turn. Do not silently fall back to the runner. The user may explicitly choose the managed runner instead.
   - Lock the transport for the logical workflow. Never move an in-progress native workflow to the CLI runner, and never treat transport selection or availability as a turn-count reset.
3. For native review:
   - Snapshot the existing sibling task names before dispatch. Choose the smallest positive workflow ordinal not already used by a sibling `doc_reviewer_workflow_<N>_stage_*`, and reserve the absent name `doc_reviewer_workflow_<N>_stage_1`.
   - Call `spawn_agent` with `agent_type="doc_reviewer"`, the reserved `task_name`, `fork_turns="none"`, `model="gpt-5.6-sol"`, the selected `reasoning_effort` (`xhigh` or `max`), and the fully rendered prompt. Do not pass conversation turns or rely on hidden caller context; the prompt and repository are the reviewer's fresh context.
   - Retain the canonical target returned by `spawn_agent` and verify through agent status that the selected role is exactly `doc_reviewer`. The reserved task name is collision control, not proof that the role loaded. If role selection cannot be verified, fail the review.
   - On an ambiguous spawn result, compare post-dispatch agent status with the pre-dispatch snapshot. Adopt the reservation only when it was absent before dispatch, now identifies exactly one newly created canonical target, and that target reports the requested role. Retry once with the same reservation only after confirming no target was created. If creation, identity, or uniqueness remains ambiguous, stop; never adopt a pre-existing role-shaped task or retry blindly.
4. For managed review, resolve this skill's absolute `SKILL.md` path and invoke the existing runner. Substitute only the effort, skill path, and prompt:

   ```bash
   agentrc-codex-doc-review \
     "{{EFFORT}}" \
     "{{DOC_SKILL_PATH}}" \
     '<fully rendered prompt>'
   ```

   Keep this argument order and do not reconstruct or extend the underlying `codex exec` pipeline. Invoke the runner directly without an `env` or `PATH` wrapper; on macOS it selects the ChatGPT app-bundled Codex when the `PATH` binary lacks its required sibling host, preserving the managed permission-rule match. The runner fixes the model and read-only sandbox, disables recursive review skills, closes stdin, suppresses trace diagnostics, discards intermediate JSONL events, emits only the final agent message on stdout plus one short status heartbeat on stderr every 15 minutes, and preserves failures. The nested reviewer inherits the normal Codex tool surface and local configuration.

   When the caller is Codex, run with `sandbox_permissions="require_escalated"` and the justification: "Run the user-authorized nested read-only Codex document review?" The managed `codex-review.rules` rule records this exact read-only command prefix. Other callers should use their normal mechanism for running the command.

5. Wait quietly for completed output:
   - Native: use event-driven agent waiting against the canonical target. Do not poll the shell, narrate unchanged snapshots, inspect partial reasoning, or relay intermediate messages. Surface only the completed reviewer response, a concrete failure or permission request, or an answer to a user status request.
   - Managed: treat the runner as a long-running synchronous process and wait passively until it exits. Let its one-line 15-minute heartbeat be the only progress update. Poll silently with the longest practical wait when attachment requires it. Notify the user only on completion, a concrete failure or blocker, a missing heartbeat for 30 minutes, or a user status request. Silence before the first heartbeat is expected.
6. Relay the verdict and findings. Verify each finding against the documents and repository context before editing. Classify it as confirmed, rejected with specific reasoning, or needing clarification. Never blindly implement or silently skip feedback.

## Re-review lifecycle

- A logical workflow permits three completed substantive reviewer turns: the initial review plus at most two re-reviews. Create its counter before selecting a transport. A completed final review response consumes one turn; failed dispatch, transport errors without completed review output, heartbeats, and partial messages do not. Replacement targets, stateless CLI invocations, and transport selection or availability do not reset the count. Ask the user before requesting a fourth completed turn. A materially new review scope starts a new workflow: disclose the reset, reserve a new smallest-unused workflow ordinal from a fresh sibling-task snapshot, restore the three-turn budget, and start from a freshly rendered initial prompt rather than replacement or follow-up context.
- Between native turns the parent may become writable to address confirmed findings, but it must be provably read-only again before `followup_task`. Address the canonical target returned by the original spawn; do not spawn another agent merely to obtain a second opinion.
- Use this fixed native follow-up content, filling every field: a unique `[review-workflow: doc_reviewer_workflow_<N>; stage:<S>; turn:<T>]` marker; the original finding identifiers; each finding's main-agent verification evidence and disposition; the exact revised spec/plan paths and sections; and a request to check both the fixes and regressions by reapplying the original rubric and output contract.
- If `followup_task` returns ambiguously, inspect only the canonical target and wait for acknowledgement or work bearing the unique marker. Resend the same marked follow-up once only when non-acceptance is confirmed. If acceptance remains ambiguous, stop rather than risking a duplicate completed turn.
- Start a replacement native target within the existing workflow only when the original target is confirmed unavailable or terminated, or the user explicitly requests a same-workflow tie-breaker. Keep the same workflow ordinal and remaining turn budget, increment only the stage suffix, reserve the exact next-stage name against a fresh sibling-task snapshot, and give the replacement the original prompt plus the workflow history needed for fresh context. If that name is already present, reconcile it as a possibly ambiguous earlier dispatch before doing anything else; do not skip to another suffix. Disclose the replacement. A terminated target is a surfaced failure, not grounds to switch transport.
- Managed re-review uses the same runner and logical-workflow counter with the exact revised document paths plus the prior finding identifiers, verification evidence, and dispositions. It does not become a new workflow merely because the runner is stateless.
- Reject every reviewer approval or escalation request. If a reviewer attempts a repository or temporary-file mutation, external message or edit, mutating connector/MCP action, browser submission, or Computer Use action, terminate the review as failed and report the attempted side effect. Read-only inspection, non-writing checks, and read-only research are the only authorized actions.

## Prompt template

```text
You are the independent reviewer for an adversarial design-document review.
Perform the review directly. Do not invoke any review skill, delegate, or launch
another Codex, Claude, OMP, or review process.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read every supplied file in full. Use your available read-only tools and
repository context where useful. Remain strictly side-effect-free: do not edit
local or external state, request approval or escalation, send messages, submit
forms, or use any mutating connector, MCP, browser, or Computer Use action.

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
- Native role unavailable before start: announce the capability fallback and use the managed runner. A generic agent is not a fallback.
- Writable or unknown parent local sandbox for a native turn: stop before dispatch and ask the user to select read-only permission; do not fall back silently.
- Missing Codex CLI or authentication on the managed path: stop and report the missing prerequisite without exposing credentials.
- Nonzero Codex exit: report the exit status and returned error; diagnose before retrying.
- Native role identity unverifiable, target unavailable or terminated, ambiguous dispatch or follow-up acceptance, or any escalation/mutation attempt: fail closed and report the exact condition. Do not switch transports.
- Long run: use the runner heartbeat as the liveness guard and keep waiting silently until exit. React only to completion, a concrete hard error, a missing heartbeat for 30 minutes, impossible progress, or a user request.
- No findings: spot-check the documents yourself before continuing.
