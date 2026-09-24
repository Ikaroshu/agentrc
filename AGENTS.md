# Agent Config Repository

This repository contains portable Codex and Claude Code configuration, not an application or package-managed build.

## Layout

- `AGENTS.md` — repository-maintenance instructions.
- `codex/AGENTS.md` — canonical cross-project instructions installed for Codex.
- `codex/config.toml` — portable baseline merged into machine-local config.
- `codex/agents/*.toml` — native roles copied as regular files to `~/.codex/agents/`.
- `codex/skills/` — skills installed into `~/.agents/skills/`.
- `codex/install.sh`, `codex/sync-remote.sh` — Codex install and remote sync.
- `claude/AGENTS.md` — canonical cross-project instructions installed for Claude Code as `~/.claude/CLAUDE.md` (Claude Code does not load a user-level `AGENTS.md`).
- `claude/settings.json` — portable baseline merged into machine-local `~/.claude/settings.json`.
- `claude/statusline.sh` — status line installed to `~/.claude/statusline.sh`.
- `claude/agents/*.md` — native subagents installed into `~/.claude/agents/`.
- `claude/skills/` — skills installed into `~/.claude/skills/`.
- `claude/install.sh`, `claude/sync-remote.sh` — Claude Code install and remote sync.
- `scripts/` — validation and config-merge helpers.
- `archive/` — inert documentation snapshots only. Follow their read-only inspection instructions; never extract, execute, source, install, sync, or copy them into active configuration.

## Common Commands

Installation and sync require `python3` with the standard-library `tomllib` module (Python 3.11+). Config merging preserves machine-only values within shared tables or objects; repository settings override matching keys. Merged files use normalized TOML or JSON formatting and omit source comments.

Codex TUI preferences are machine-local; keep `[tui]` out of the portable baseline so deployment preserves each machine's customizations.

```bash
./install.sh
./sync-remote.sh <ssh-host>
./codex/install.sh
./codex/sync-remote.sh <ssh-host>
./claude/install.sh
./claude/sync-remote.sh <ssh-host>
./scripts/validate-config.sh
```

Prefer the root entrypoints for machine setup, which install or sync both harnesses; use the per-harness scripts directly when appropriate. Validate after every config change.

## Editing Rules

- Keep cross-project behavioral instructions in `codex/AGENTS.md` and `claude/AGENTS.md`; keep repository-maintenance instructions here. Apply a harness-neutral instruction change to both files, and keep their differences limited to harness runtime mechanics. Do not add a separate `CLAUDE.md` source.
- Keep each harness self-contained: skills under `<harness>/skills/` and roles or subagents under `<harness>/agents/` as regular harness-owned files; add no shared or compatibility paths. Keep the Claude workflow skills and subagents equivalent to their Codex counterparts except for runtime dispatch (`Agent` with `subagent_type`, `SendMessage` for follow-ups) and model settings.
- Install and sync must preserve machine-specific config and settings, project trust, notices, marketplaces, plugins, permissions, environment values, skill paths, app-managed settings, unrelated rules, skills, or subagents, and unmanaged legacy OMP state.
- Paths inside portable config should prefer `~/` when the harness supports it. Absolute paths are acceptable only for machine-local state that the harness itself records.
- Shell scripts use `set -euo pipefail` and remain simple enough to review without a framework.

## Instruction Authoring

- Keep durable cross-project preferences and stage routing in `codex/AGENTS.md`; keep stage-specific mechanics in the owning skill and role-specific obligations in the native role.
- Write short, discriminating skill descriptions. Prefer outcomes and decision criteria to generic advice, repeated procedure, or fixed announcement scripts. Preserve real requirements and authorization boundaries.
- Keep short skills self-contained. Use linked references for substantial conditional detail and load only the relevant reference.

## Testing

There is no app test suite. `./scripts/validate-config.sh` checks topology, permissions, syntax, role and subagent definitions, config merging, local installation, and remote-sync behavior for both harnesses.

## Git Workflow

- This repository overrides the cross-project development workflow: skip the brainstorm, worktree, implement, code-review, and merge stages and their skills unless the user asks for them. Edit directly on `main`, validate, and commit.
- Run `./scripts/validate-config.sh` before committing. Never install or sync from a feature worktree.
- After a merge or direct commit on `main`, run `./install.sh` and `./sync-remote.sh mini` from main without separate authorization. Verify local and remote active files match committed sources without disturbing unrelated state. When changes affect roles, dispatch, or installation, start fresh installed-role canaries for each affected harness locally and remotely where its runtime exists. Fix canary failures forward; never leave installation pointing at a deleted worktree.
