# Agent Config Repository

This repository tracks portable configuration for AI coding agents such as Claude Code and Codex. It is a config repo made of shell scripts, symlinks, and settings files; it is not an application with a package manager or build system.

## Layout

- `AGENTS.md` — canonical repo-level instructions for all agents working in this repository.
- `CLAUDE.md -> AGENTS.md` — Claude compatibility symlink; edit `AGENTS.md`, not `CLAUDE.md`.
- `shared/AGENTS.md` — canonical cross-project personal agent instructions.
- `shared/skills/` — canonical shared skills used by more than one agent.
- `claude/` — files installed into `~/.claude/`.
  - `CLAUDE.md -> ../shared/AGENTS.md`
  - `settings.json`
  - `commands/`
  - `skills/auto-research/SKILL.md -> ../../../shared/skills/auto-research/SKILL.md`
  - `install.sh`
  - `sync-remote.sh`
- `codex/` — files installed into `~/.codex/`.
  - `AGENTS.md -> ../shared/AGENTS.md`
  - `config.toml`
  - `skills/auto-research/SKILL.md -> ../../../shared/skills/auto-research/SKILL.md`
  - `install.sh`
  - `sync-remote.sh`
- `scripts/` — validation and merge helpers used by install/sync scripts.

## Common Commands

Use the root scripts when setting up a machine:

```bash
./install.sh
./sync-remote.sh <ssh-host>
```

Use tool-specific scripts when only one agent needs to change:

```bash
./claude/install.sh
./codex/install.sh
./claude/sync-remote.sh <ssh-host>
./codex/sync-remote.sh <ssh-host>
```

Validate the repository after every config change:

```bash
./scripts/validate-config.sh
```

## Editing Rules

- Keep behavioral instructions in `shared/AGENTS.md` unless the instruction is only about maintaining this repository.
- Keep skills shared by Claude and Codex in `shared/skills/`; point tool-specific skill paths at the shared source.
- Keep repo maintenance instructions in root `AGENTS.md`.
- Do not edit symlink targets through the compatibility symlink paths when the canonical path is clearer.
- Preserve machine-specific settings during remote syncs:
  - Claude sync may preserve remote-only settings such as environment and permissions.
  - Codex sync must preserve remote project trust, notices, marketplaces, and skill path entries.
- Paths inside portable config should prefer `~/` when the tool supports it. Absolute paths are acceptable only for machine-local Codex state that the CLI itself records.
- Shell scripts should use `set -euo pipefail` and stay simple enough to review without a framework.

## Testing

There is no app test suite. The repo-level validation script is the required check. It verifies expected symlinks, executable bits, shell syntax, JSON/TOML syntax, and Codex config merge behavior.
