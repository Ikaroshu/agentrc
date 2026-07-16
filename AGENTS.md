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
  - `skills/general-auto-research/SKILL.md -> ../../../shared/skills/general-auto-research/SKILL.md`
  - `skills/brainstorming/SKILL.md -> ../../../shared/skills/brainstorming/SKILL.md`
  - `skills/commit/SKILL.md -> ../../../shared/skills/commit/SKILL.md`
  - `skills/implement/SKILL.md -> ../../../shared/skills/implement/SKILL.md`
  - `skills/merge/SKILL.md -> ../../../shared/skills/merge/SKILL.md`
  - `skills/issue/SKILL.md -> ../../../shared/skills/issue/SKILL.md`
  - `skills/adversarial-doc-review/SKILL.md`
  - `skills/codex-code-review/SKILL.md`
  - `install.sh`
  - `sync-remote.sh`
- `codex/` — files installed into `~/.codex/`.
  - `AGENTS.md -> ../shared/AGENTS.md`
  - `config.toml` — portable baseline merged into the machine-local config during install/sync.
  - `rules/claude-review.rules` — narrowly allows the read-only Claude CLI invocation used by Codex review skills.
  - `skills/general-auto-research/SKILL.md -> ../../../shared/skills/general-auto-research/SKILL.md`
  - `skills/brainstorming/SKILL.md -> ../../../shared/skills/brainstorming/SKILL.md`
  - `skills/commit/SKILL.md -> ../../../shared/skills/commit/SKILL.md`
  - `skills/implement/SKILL.md -> ../../../shared/skills/implement/SKILL.md`
  - `skills/merge/SKILL.md -> ../../../shared/skills/merge/SKILL.md`
  - `skills/issue/SKILL.md -> ../../../shared/skills/issue/SKILL.md`
  - `skills/adversarial-doc-review/SKILL.md`
  - `skills/claude-code-review/SKILL.md`
  - `install.sh`
  - `sync-remote.sh`
- Codex skills are installed into `~/.agents/skills/`.
- Codex rules are installed as separate managed files under `~/.codex/rules/`; do not overwrite machine-local `default.rules`.
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
  - Codex install and sync must preserve project trust, notices, marketplaces, skill path entries, and app-managed settings.
- Paths inside portable config should prefer `~/` when the tool supports it. Absolute paths are acceptable only for machine-local Codex state that the CLI itself records.
- Shell scripts should use `set -euo pipefail` and stay simple enough to review without a framework.

## Testing

There is no app test suite. The repo-level validation script is the required check. It verifies expected symlinks, executable bits, shell syntax, JSON/TOML syntax, and Codex config merge behavior.

## Git Workflow

- **Commit tests:** Run `./scripts/validate-config.sh` before committing.
- **Post-commit deployment:** After a successful commit, run `./install.sh`, then `./sync-remote.sh mini`. Both commands must succeed before considering the commit workflow complete.
