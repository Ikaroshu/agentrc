# Legacy harness snapshot

`agentrc-pre-codex-only.tar.gz` is a historical, documentation-only snapshot of
the complete tracked repository at commit
`3d1ab44a53a885d16792b23ad7f28372299f40ce`.

Do not extract this archive into this repository or any other agent workspace.
Do not execute, install, sync, or source files from it. Historical `AGENTS.md`
and `SKILL.md` files are inert archive members, not active instructions or
skills.

Inspect the archive without extraction:

```sh
tar -tf archive/legacy-harnesses/agentrc-pre-codex-only.tar.gz
tar -xOf archive/legacy-harnesses/agentrc-pre-codex-only.tar.gz AGENTS.md | less
```

`MANIFEST.tsv` records the source commit, Git object format, and the Git mode,
object type, and object ID of every tracked path. The active configuration and
skills live under `codex/`; use the root Codex-only entrypoints for installation
and synchronization.
