# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository tracks and manages configurations and settings for AI tools (Claude Code, Codex, etc.). It is a collection of shell scripts, config files, and hooks — not an application with a build system.

## Repository Structure

Each AI tool gets its own top-level directory mirroring its config location:

- `claude/` — Claude Code (`~/.claude/`)
  - `settings.json`, `CLAUDE.md`, `RTK.md`, `file-suggestion.sh`, `statusline-command.sh`
  - `hooks/` — PreToolUse hooks (RTK rewrite)
  - `commands/` — slash commands (commit, merge)
  - `install.sh` / `sync-remote.sh`
- `codex/` — Codex CLI (`~/.codex/`)
  - `AGENTS.md`, `config.toml`
  - `install.sh` / `sync-remote.sh`

## Setup

Each tool directory has the same two scripts:

- `install.sh` — local machine: symlinks repo files into the tool's config dir
- `sync-remote.sh <host>` — remote machine: copies files, merges machine-specific settings

```bash
./claude/install.sh          # local symlinks for Claude
./codex/install.sh           # local symlinks for Codex
./claude/sync-remote.sh mini # sync Claude to remote
./codex/sync-remote.sh mini  # sync Codex to remote
```

## Conventions

- Paths in config files must use `~/` (not absolute paths) for portability
- Shell scripts should be POSIX-compatible where possible
- `sync-remote.sh` merges settings files to preserve machine-specific config (env vars, project trust, permissions mode)
