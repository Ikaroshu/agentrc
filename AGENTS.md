# Agent Config Repository

This repository contains portable Codex and Claude Code configuration, not an application or package-managed build.

## Layout

- `AGENTS.md` — repository-maintenance instructions.
- `codex/` — Codex's `AGENTS.md` (cross-project instructions), `config.toml` (baseline merged into machine-local config), `agents/*.toml` (native roles copied as regular files to `~/.codex/agents/`), `skills/` (installed into `~/.agents/skills/`), `install.sh`, and `sync-remote.sh`.
- `claude/` — Claude Code's `AGENTS.md` (installed as `~/.claude/CLAUDE.md`, because Claude Code does not load a user-level `AGENTS.md`), `settings.json` (baseline merged into `~/.claude/settings.json`), `statusline.sh`, `agents/*.md` (`Explore.md` and `general-purpose.md` replace the built-ins of those names to set their model and effort), `skills/`, `install.sh`, and `sync-remote.sh`.
- `herdr-app/` — Herdr app mods, layout, key bindings, and settings for this Mac only; `herdr-app/install.sh`, run with the app open, copies the mods and layout into `~/.config/herdr-app/`, merges `keys.json` and `settings.json`, and switches to the `main-titled` layout when another shows. Remote machines run only herdr-core, so never sync these.
- `scripts/` — validation and config-merge helpers.
- `archive/` — inert documentation snapshots only. Follow their read-only inspection instructions; never extract, execute, source, install, sync, or copy them into active configuration.

## Common Commands

Installation and sync require `python3` with the standard-library `tomllib` module (Python 3.11+). Config merging preserves machine-only values within shared tables or objects; repository settings override matching keys, except that Claude settings lists append missing repository entries to machine entries (removing a repository entry does not remove it from machines). Merged files use normalized TOML or JSON formatting and omit source comments.

Codex TUI preferences are machine-local; keep `[tui]` out of the portable baseline so deployment preserves each machine's customizations.

```bash
./install.sh
./sync-remote.sh <ssh-host>
./codex/install.sh
./codex/sync-remote.sh <ssh-host>
./claude/install.sh
./claude/sync-remote.sh <ssh-host>
./herdr-app/install.sh
./scripts/validate-config.sh
```

Prefer the root entrypoints for machine setup, which install or sync both harnesses; use the per-harness scripts directly when appropriate. Validate after every config change.

## Editing Rules

- Keep cross-project behavioral instructions in `codex/AGENTS.md` and `claude/AGENTS.md`; keep repository-maintenance instructions here. Keep every section except Development Workflow identical in both files; Development Workflow differs by role (Claude coordinates, Codex executes) and harness runtime mechanics. Do not add a separate `CLAUDE.md` source.
- Keep each harness self-contained: skills under `<harness>/skills/` and roles or subagents under `<harness>/agents/` as regular harness-owned files; add no shared or compatibility paths. Skills present in both harnesses stay equivalent except for runtime mechanics. Only Claude has the `spec`, `codex`, and `research` workflow skills.
- Install and sync must preserve machine-specific config and settings, project trust, notices, marketplaces, plugins, permissions, environment values, skill paths, app-managed settings, unrelated rules, skills, or subagents, and unmanaged legacy OMP state.
- Paths inside portable config should prefer `~/` when the harness supports it. Absolute paths are acceptable only for machine-local state that the harness itself records.
- Shell scripts use `set -euo pipefail` and remain simple enough to review without a framework.

## Instruction Authoring

- A line earns its place only if a capable model would otherwise get it wrong here: personal policy, a repository requirement, or a known failure. Leave out standard tool usage and general advice, and explain why only where a rule would otherwise look arbitrary.
- Keep durable cross-project preferences and stage routing in `AGENTS.md`; keep stage-specific mechanics in the owning skill and role-specific obligations in the native role. Keep each rule in one place. Do not restate an installed tool manual in a skill.
- Write short, discriminating skill descriptions in the third person that say what the skill does and when to use it. Preserve real requirements and authorization boundaries.
- Keep short skills self-contained. Use linked references for substantial conditional detail and load only the relevant reference.

## Testing

There is no app test suite. `./scripts/validate-config.sh` checks topology, permissions, syntax, role and subagent definitions, config merging, local installation, and remote-sync behavior for both harnesses.

## Git Workflow

- Assume work in this repository is trivial under the cross-project development workflow unless the user asks for a spec. Work on `main`; once the plan is approved, validate, commit, and push `main` to `origin` without separate authorization.
- Run `./scripts/validate-config.sh` before committing. Never install or sync from a feature worktree.
- After a merge or direct commit on `main`, run `./install.sh` and `./sync-remote.sh mini` from main without separate authorization, plus `./herdr-app/install.sh` on this Mac when `herdr-app/` changed. Edit the mods here, not in `~/.config/herdr-app/`, so installation does not overwrite live edits. Verify local and remote active files match committed sources without disturbing unrelated state. When changes affect roles, dispatch, or installation, start fresh installed-role canaries for each affected harness locally and remotely where its runtime exists. Fix canary failures forward; never leave installation pointing at a deleted worktree. Install and sync do not remove a deleted skill, so remove its installed copies by hand on each machine.
