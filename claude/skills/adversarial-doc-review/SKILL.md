---
name: adversarial-doc-review
description: Run a Codex-backed adversarial review of a spec and/or implementation plan via `codex exec`. Use after writing spec/plan docs (typically in `.superpowers/specs/` and `.superpowers/plans/`) and before starting implementation. Returns the reviewer's findings inline so they can be addressed in the same turn.
---

# Adversarial Doc Review

A homebrewed replacement for the `/codex:adversarial-review` plugin command. Shells out to the local Codex CLI (`codex exec`) with a critical-reviewer prompt aimed at spec and plan documents (not code). The Codex plugin is unstable for this use case; this skill is narrower, predictable, and runs synchronously.

## When to use

- After writing a spec and/or plan (typically under `<project-root>/.superpowers/specs/` and `<project-root>/.superpowers/plans/`), before implementation begins.
- The skill reviews **documents**, not code diffs. Do not use it as a code reviewer — use `/code-review` or `/ultrareview` for code.

## Prerequisites

- `codex` CLI on PATH. Verify with `command -v codex` if uncertain.
- Run from the **main repo cwd on the main branch**, NOT from inside a worktree. Spec/plan files live at stable paths under `.superpowers/`; worktrees are ephemeral and the relative paths get confused.

## Arguments

The caller (Claude) supplies explicit file paths to review:

- **`--spec <path>`** — path to the spec file (optional if only reviewing a plan).
- **`--plan <path>`** — path to the plan file (optional if only reviewing a spec).
- **`--focus <text>`** — optional extra guidance to weight the review (e.g. "weight risk of race conditions heavily").

At least one of `--spec` or `--plan` must be provided. Paths may be absolute or relative to the current working directory.

## Workflow

1. **Validate inputs.** Confirm each supplied path exists and is a regular file. If a path is missing, stop and report it — do not silently fall back to auto-discovery.

2. **Build the review prompt.** Use the template below verbatim, substituting the absolute paths of the supplied files. Include the `--focus` text under "Reviewer focus" if provided.

3. **Run Codex.** Invoke the CLI exactly like this (single Bash call, no backgrounding):

   ```bash
   codex exec \
     --skip-git-repo-check \
     --sandbox read-only \
     --color never \
     "$PROMPT"
   ```

   - `--sandbox read-only` is required: the reviewer must not edit files.
   - `--color never` keeps stdout clean for relay to the user.
   - Do **not** pass `--json`; we want the plain final message.
   - Do **not** background the call. The review must complete in the same turn so findings can be acted on.

4. **Relay findings.** Show the user the reviewer's verdict and findings. Then either:
   - **Address findings** in the spec/plan and re-run the skill to verify, or
   - **Defend the design** with reasoning if a finding is wrong — but do this explicitly, don't quietly ignore.

## Prompt template

Substitute `{{SPEC_PATH}}`, `{{PLAN_PATH}}`, and `{{FOCUS_BLOCK}}` (or omit a line entirely if its file wasn't provided).

```
You are an adversarial reviewer of design documents (a spec and/or an
implementation plan). Your job is to find the strongest objections a senior
engineer would raise before any code is written.

Files to review:
- Spec: {{SPEC_PATH}}
- Plan: {{PLAN_PATH}}

Read both files in full from disk before saying anything.

{{FOCUS_BLOCK}}

Evaluate, in this order:

1. Correctness & completeness
   - Does the spec actually describe the problem and constraints, or hand-wave?
   - Does the plan's approach satisfy the spec? Any gap, contradiction, or
     unstated assumption?
   - Edge cases the plan ignores (empty inputs, concurrency, partial failure,
     idempotency, large inputs, time zones, ordering)?

2. Risk & blast radius
   - What's the worst thing that breaks if the plan is wrong? Data loss?
     Silent corruption? Cascading failures? Reversibility?
   - Migrations, schema changes, or destructive operations without a rollback?

3. Design & alternatives
   - Is the proposed approach the simplest viable one, or over-engineered?
   - Are there obvious alternatives the plan dismissed without justification?
   - Premature abstractions, speculative generality, or features-not-asked-for?

4. Testability & verification
   - How will we know it actually works? Are the verification steps real
     (commands, expected outputs) or vague ("test the feature")?
   - What tests are missing? What's untestable as written?

5. Process & scope
   - Anything not in the spec that the plan quietly added? (Scope creep.)
   - Anything in the spec the plan silently dropped?

Output format — use these exact section headers, in order:

## Verdict
One sentence: APPROVE / APPROVE WITH CHANGES / REWORK. Then one sentence of why.

## Blocking findings
Numbered list. Each item: (1) what is wrong, (2) why it matters, (3) the
minimum change that would fix it. Cite file + line range or section heading.
If none, write "None.".

## Non-blocking suggestions
Numbered list, same shape but lower stakes. If none, write "None.".

## Questions for the author
Numbered list of clarifications needed before this can be approved. If none,
write "None.".

Rules:
- Be specific. "Consider error handling" is useless; "Section 3 doesn't say
  what happens when the upload partially completes" is useful.
- No flattery, no restating the doc. Land critique, not summary.
- If the doc is genuinely solid, APPROVE and keep the rest short. Do not
  manufacture findings.
```

## Failure modes & guidance

- **Codex hangs or times out.** `codex exec` is synchronous; if it stalls, kill it (Ctrl-C) and report. Do not retry blindly — diagnose first (CLI version, auth, network).
- **Reviewer cites files outside the supplied paths.** That's fine if it's reading repo context for grounding; flag it only if the review drifts away from the doc.
- **Reviewer wants to edit files.** It cannot — `--sandbox read-only` blocks writes. The verdict and findings are the deliverable.
- **No findings at all + APPROVE.** Trust it but spot-check the doc yourself before moving to implementation; don't treat APPROVE as a rubber stamp.
- **Inside a worktree.** Stop and switch back to the main repo cwd on `main` before running. Spec/plan paths under `.superpowers/` are relative to project root and the reviewer expects to find them there.
