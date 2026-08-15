# Retired Portseer Claude configuration

`portseer-claude-20260815.tar.gz` is an inert documentation-only snapshot of
Portseer's retired local `.claude/` configuration. The compatibility `skills`
symlink was deliberately omitted because Portseer's active project skills live
under `.agents/skills/`.

Do not extract this archive into an agent workspace. Do not execute, install,
sync, source, or otherwise use its hooks or settings as active configuration.
The archived settings contain stale absolute paths and Claude-specific
permissions.

Inspect it without extraction:

```sh
tar -tf archive/portseer-claude/portseer-claude-20260815.tar.gz
tar -xOf archive/portseer-claude/portseer-claude-20260815.tar.gz .claude/settings.local.json
```
