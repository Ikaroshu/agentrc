# Agent Config Repository

This repository tracks portable Codex configuration. It is a config repository made of shell scripts, skills, role definitions, and settings files; it is not an application with a package manager or build system.

## Layout

- `AGENTS.md` — repository-maintenance instructions.
- `codex/AGENTS.md` — canonical cross-project instructions installed for Codex.
- `codex/config.toml` — portable baseline merged into machine-local Codex configuration.
- `codex/agents/*.toml` — portable native roles copied as regular files into `~/.codex/agents/`.
- `codex/skills/` — canonical Codex skills installed into `~/.agents/skills/`.
- `codex/install.sh` and `codex/sync-remote.sh` — Codex-only local installation and remote synchronization.
- `archive/legacy-harnesses/` — an inert documentation-only snapshot of the former multi-harness repository. Inspect it with the read-only commands in its README; never extract it into an agent workspace or install, sync, execute, source, or otherwise use its contents as active configuration.
- `archive/portseer-claude/` — an inert documentation-only snapshot of retired Portseer Claude-local configuration. Never extract, execute, install, sync, or source it.
- `scripts/` — active validation and Codex configuration merge helpers.

## Common Commands

Use the root entrypoints when setting up a machine:

```bash
./install.sh
./sync-remote.sh <ssh-host>
```

Use the Codex scripts directly when appropriate:

```bash
./codex/install.sh
./codex/sync-remote.sh <ssh-host>
```

Validate the repository after every config change:

```bash
./scripts/validate-config.sh
```

## Editing Rules

- Keep cross-project behavioral instructions in `codex/AGENTS.md`; keep repository-maintenance instructions here.
- Keep every active skill under `codex/skills/` and every active role under `codex/agents/` as a regular Codex-owned file. Do not add shared or compatibility paths.
- Treat `archive/` as historical documentation only. Active scripts must never extract, source, execute, install, sync, or copy runtime content from it.
- Codex install and sync must preserve machine-specific config, project trust, notices, marketplaces, skill path entries, app-managed settings, unrelated rules, unrelated skills, and legacy Claude/OMP state that this repository no longer manages.
- Paths inside portable config should prefer `~/` when Codex supports it. Absolute paths are acceptable only for machine-local state that Codex itself records.
- Shell scripts should use `set -euo pipefail` and stay simple enough to review without a framework.

## Testing

There is no app test suite. The repository validation script is the required check. It verifies the inert archive, active Codex topology, executable bits, shell and TOML syntax, configuration merge behavior, local installation, and exact remote-sync destinations and commands.

## Git Workflow

- **Commit tests:** Run `./scripts/validate-config.sh` before committing.
- **Feature-worktree commits:** Run validation, but do not install or sync from a feature worktree.
- **Post-merge deployment only:** From the main checkout on `main`, run `./install.sh` and `./sync-remote.sh mini`, verify installed local and remote active files match the merged sources without changing the protected legacy state, and start a fresh global Codex task or process for installed-role canaries. If a canary fails, report the deployment failure and fix forward; do not leave installation pointed at a deleted worktree. A remote live-role canary is required only when that machine exposes the collaboration runtime.
