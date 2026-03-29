# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository tracks and manages configurations and settings for AI tools (Claude Code, Codex, etc.). It is a collection of shell scripts, config files, and hooks — not an application with a build system.

## Repository Structure

- `claude/` — Claude Code global settings, mirroring `~/.claude/` structure
  - `settings.json` — main config (permissions, hooks, plugins, statusline)
  - `CLAUDE.md`, `RTK.md` — global instructions
  - `file-suggestion.sh` — `@`-autocomplete hook (rg + fzf)
  - `statusline-command.sh` — status line display script
  - `hooks/` — PreToolUse hooks (e.g., RTK rewrite)
  - `commands/` — slash commands (commit, merge workflows)
  - `install.sh` — symlinks repo files into `~/.claude/` (local machine setup)
  - `sync-remote.sh` — rsync files to a remote machine's `~/.claude/`

## Setup

**Local machine** (symlink approach — edits in either place are the same file):
```bash
./claude/install.sh
```

**Remote machine** (copy approach):
```bash
./claude/sync-remote.sh mini
```

## Conventions

- Paths in `settings.json` must use `~/.claude/...` (not absolute paths) for portability
- Shell scripts should be POSIX-compatible where possible; bash-specific features are acceptable when needed
- New AI tool configs go in their own top-level directory (e.g., `claude/`, `codex/`)
