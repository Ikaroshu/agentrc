# Agent Config Repository

This repository contains portable Codex configuration, not an application or package-managed build.

## Layout

- `AGENTS.md` — repository-maintenance instructions.
- `codex/AGENTS.md` — canonical cross-project instructions installed for Codex.
- `codex/config.toml` — portable baseline merged into machine-local config.
- `codex/agents/*.toml` — native roles copied as regular files to `~/.codex/agents/`.
- `codex/skills/` — skills installed into `~/.agents/skills/`.
- `codex/install.sh`, `codex/sync-remote.sh` — Codex install and remote sync.
- `scripts/` — validation and config-merge helpers.
- `archive/` — inert documentation snapshots only. Follow their read-only inspection instructions; never extract, execute, source, install, sync, or copy them into active configuration.

## Common Commands

Installation and sync require `python3` with the standard-library `tomllib` module (Python 3.11+). Config merging preserves machine-only values within shared tables; repository settings override matching keys. The merged file uses normalized TOML formatting and omits source comments.

```bash
./install.sh
./sync-remote.sh <ssh-host>
./codex/install.sh
./codex/sync-remote.sh <ssh-host>
./scripts/validate-config.sh
```

Prefer the root entrypoints for machine setup; use the Codex scripts directly when appropriate. Validate after every config change.

## Editing Rules

- Keep cross-project behavioral instructions in `codex/AGENTS.md`; keep repository-maintenance instructions here.
- Keep active skills under `codex/skills/` and roles under `codex/agents/` as regular Codex-owned files; add no shared or compatibility paths.
- Install and sync must preserve machine-specific config, project trust, notices, marketplaces, skill paths, app-managed settings, unrelated rules or skills, and unmanaged legacy Claude/OMP state.
- Paths inside portable config should prefer `~/` when Codex supports it. Absolute paths are acceptable only for machine-local state that Codex itself records.
- Shell scripts use `set -euo pipefail` and remain simple enough to review without a framework.

## Instruction Authoring

- Keep durable cross-project preferences and stage routing in `codex/AGENTS.md`; keep stage-specific mechanics in the owning skill and role-specific obligations in the native role.
- Write short, discriminating skill descriptions. Prefer outcomes and decision criteria to generic advice, repeated procedure, or fixed announcement scripts. Preserve real requirements and authorization boundaries.
- Keep short skills self-contained. Use linked references for substantial conditional detail and load only the relevant reference.

## Testing

There is no app test suite. `./scripts/validate-config.sh` checks topology, permissions, syntax, config merging, local installation, and remote-sync behavior.

## Git Workflow

- Run `./scripts/validate-config.sh` before committing. Never install or sync from a feature worktree.
- After a merge or direct commit on `main`, run `./install.sh` and `./sync-remote.sh mini` from main without separate authorization. Verify local and remote active files match committed sources without disturbing unrelated state. When changes affect roles, dispatch, or installation, start fresh installed-role canaries locally and remotely where the collaboration runtime exists. Fix canary failures forward; never leave installation pointing at a deleted worktree.
