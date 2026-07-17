---
name: code-review
description: Run an OMP-backed review of a git diff through OpenRouter's Pareto coding router. Estimates an easy, medium, or hard tier, announces it transparently, and returns actionable findings for verification before merge.
---

# Code Review

Use the local OMP `review` profile as a neutral third-party code reviewer. The profile routes through OpenRouter's Pareto coding router and exposes only `read`, `grep`, and `glob`; it cannot edit files or run commands.

## Prerequisites

- `omp` is on `PATH`.
- The OMP `review` profile is installed by `agentrc/omp/install.sh`.
- `~/.omp/agent/.env` contains `OPENROUTER_API_KEY`.
- Run from the working tree containing the changes.

## Arguments and scope

Choose exactly one scope:

- `--base <branch>`: current branch against the merge base with `<branch>`.
- `--commit <sha>`: one commit.
- `--uncommitted`: staged, unstaged, and untracked work.

Optional arguments:

- `--focus <text>`: review emphasis.
- `--difficulty <easy|medium|hard>`: explicit tier override.

Confirm the selected scope contains changes before invoking OMP.

## Select the review tier

Honor an explicit `--difficulty`. Otherwise estimate from the diff and affected contracts:

- **Easy**: small, localized, familiar change with no public contract, persistent state, concurrency, security, or data-loss implications.
- **Medium**: multi-file behavior or a meaningful contract/state change whose blast radius remains localized.
- **Hard**: architecture or cross-system work; public APIs or schemas; migrations; concurrency; security; data-loss risk; high blast radius; or substantial ambiguity.

Round upward when signals are mixed. Tell the user the tier and one-sentence rationale, then proceed immediately unless the user objects or supplied an override.

Map tiers exactly:

- easy: `pareto-easy/openrouter/pareto-code`
- medium: `pareto-medium/openrouter/pareto-code`
- hard: `pareto-hard/openrouter/pareto-code`

## Build the review bundle

Create a unique file with `mktemp /private/tmp/omp-code-review.XXXXXX.diff` in one command, then use its returned literal path in later commands.

Write the relevant status, summary, and patch into that file:

- `--base`: `git status --short`, `git diff --stat <base>...HEAD`, and `git diff --find-renames --binary <base>...HEAD`.
- `--commit`: `git status --short`, `git show --stat --find-renames <sha>`, and `git show --find-renames --binary <sha>`.
- `--uncommitted`: `git status --short`, `git diff --stat HEAD`, and `git diff --find-renames --binary HEAD`.

For uncommitted work, untracked files appear only in the status section; the prompt requires OMP to read each listed untracked file directly. Keep bundle creation separate from the OMP invocation so the permission rule sees a literal command prefix.

## Run OMP

Render the prompt below with the literal bundle path, scope, focus, and tier. Use this exact argument order, substituting only the model and final prompt:

```bash
omp --profile review \
  -p \
  --no-session \
  --no-extensions \
  --no-skills \
  --no-rules \
  --no-lsp \
  --tools read,grep,glob \
  --approval-mode always-ask \
  --model pareto-medium/openrouter/pareto-code \
  '<fully rendered prompt>'
```

Pass the prompt as one literal argument. Do not add shell wrappers, environment prefixes, redirects, extra tools, extensions, skills, rules, or MCP configuration. Codex's managed permission rule matches this fixed read-only command shape.

Start with a 30-second yield. If OMP is still running, poll every 60 seconds until it exits; silence alone is not a failure. Remove the temporary bundle after the review process exits.

## Prompt template

```text
You are a senior code reviewer. Review tier: {{TIER}}.
Review scope: {{SCOPE}}.
The prepared status, summary, and patch are in {{BUNDLE_PATH}}.

Read the bundle in full, then inspect the changed files and relevant surrounding
repository code with read, grep, and glob. For uncommitted scope, read every
untracked file named in the status section. Do not edit files and do not run commands.

{{FOCUS_BLOCK}}

Find only actionable issues: correctness bugs, regressions, broken contracts,
missing tests for changed behavior, security or data-loss risks, and
maintainability problems that materially affect this change. Do not flag style
preferences. Do not claim tests passed because you cannot run commands.

Output these exact sections:

## Findings
Numbered list ordered by severity. Each item must include severity, confidence,
file and line, problem, impact, and minimum fix. Write "None." if empty.

## Test gaps
Important missing verification, or "None.".

## Residual risk
One short paragraph.

Read relevant changed files before finalizing. Do not approve by default and do
not manufacture findings.
```

## Handle findings

Relay the review summary. Before any edit, verify each finding against the code and original change intent. Classify it as confirmed, rejected with specific reasoning, or needing clarification. Fix only confirmed findings, and never silently ignore feedback.

## Failure handling

- Empty scope: choose the correct selector or stop.
- Missing OMP profile or API key: report the missing prerequisite without printing secret values.
- Nonzero OMP exit: report the exit status and returned error; diagnose before retrying.
- Harness limitation: OMP cannot run tests in this profile; local validation remains authoritative.
- No findings: spot-check the diff yourself before merging.
