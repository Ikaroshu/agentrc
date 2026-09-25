# Herdr setup

Portable settings captured from the working macOS setup on 2026-09-24, using
Herdr 0.9.1. This directory is installed separately from the root Codex/Claude
entrypoints. It does not copy workspaces, sessions, SSH machine profiles, plugin
checkouts, logs, or caches.

## Included settings

- One Dark with UI background, selection, and text colors from the installed
  VS Code One Dark Pro theme (`zhuangtongfa.material-theme` 3.20.2).
- Symbol status indicators and no new-tab name prompt.
- **Ctrl+\, then E** toggles the file sidebar; one press opens or closes it.
- Unified file/git sidebar on the left, width 32, opened manually, following the
  working directory. File previews open in a pane.
- Agent sidebar width 36 (maximum 44), with three rows: agent/status, task title,
  and machine/workspace. Codex and Claude have distinct label colors.
- Automatic tab naming and tab context stay on; numeric prefixes are off.

| Plugin | Purpose |
| --- | --- |
| [alexarthurs/herdr-sidebar](https://github.com/alexarthurs/herdr-sidebar) | File explorer, previews, git controls |
| [qu8n/herdr-automatic-rename](https://github.com/qu8n/herdr-automatic-rename) | Automatic tab names |

`plugins.tsv` records the installed source commits. The installer requests those
commits rather than a moving branch. The sidebar's upstream build hook downloads
its release binary or builds with Cargo; the source commit alone does not pin
that release asset's bytes. Updating a plugin can change the settings it reads.

## Local setup

Use macOS or Linux with zsh. Install [Herdr](https://herdr.dev), jq, Git, curl,
and Python 3.11+ first. The sidebar may need Rust 1.89+ when no prebuilt binary
is available. On macOS with Homebrew:

```sh
brew install herdr jq python
./herdr/install.sh
```

Run this from a login shell where `herdr`, `jq`, and `python3` resolve. The
installer writes the settings files, adds a zsh hook without replacing `.zshrc`,
installs the plugins, and links `herdr-sidebar` into `~/.local/bin`.
Plugin installation runs the upstream build hooks. These scripts use the default
`~/.config` and `~/.local/state` locations; do not use them with custom XDG/Herdr
config paths.

The default installer refuses existing settings before writing anything. To
update an existing installation, run:

```sh
./herdr/install.sh --merge
```

Merge mode applies repository values while preserving unrelated Herdr settings,
custom command bindings on other keys, sidebar state, and rename options.
It updates the managed shell hook and plugin revisions; `.zshrc` is retained.
TOML formatting is normalized and comments are removed. Other plugins and live
workspaces/sessions are not copied or removed. The `herdr-sidebar` symlink is
updated; an existing regular executable at that path must be moved first.

If a plugin download/build fails, fix the reported cause and rerun with
`--merge`; errors stop deployment and already-applied settings remain in place.

Open a new shell (or source `~/.config/herdr/agentrc.zsh`), select a Nerd Font,
then launch `herdr`. In a Herdr shell, from this repository, run:

```sh
./herdr/activate.sh
```

This reloads settings and applies automatic naming without number prefixes.
No Herdr server restart is needed. `herdr-sidebar --preview` is an internal
viewer command requiring control data; open a file through the sidebar instead.

## Fonts

Use **MesloLGS NF**, including all four faces, from
[Powerlevel10k's font instructions](https://github.com/romkatv/powerlevel10k#fonts).
In iTerm, select it under **Settings → Profiles → Text**, including the separate
Non-ASCII font if enabled. The previously installed **MesloLGS NF Herdr** also
remains usable. No custom font build or Node runtime is required.

The font belongs on the machine rendering the terminal, even when Herdr runs on
an SSH host. A remote host does not need its terminal font changed. The Herdr UI
palette does not change colors inside terminal applications or the independently
themed file-sidebar plugin.

## Remote hosts

**Deploy on each machine that runs Herdr**, including SSH hosts. Installing a
plugin locally does not install it on a machine selected in Herdr's sidebar.
The root `./sync-remote.sh` handles Codex and Claude only. Use this separate
command for both Herdr plugins and the saved settings:

```sh
./herdr/sync-remote.sh mini
```

The remote host needs zsh and the same prerequisites as local setup. This copies
a setup bundle to `~/.local/share/agentrc-herdr/`, then runs the installer with
`--merge` through a login shell. It works for fresh and existing settings.
It leaves server startup to you so it does not interrupt running agents.
For an already-running server, activate the deployed settings:

```sh
ssh mini 'zsh -lc '\''~/.local/share/agentrc-herdr/herdr/activate.sh'\'''
```

Open new remote shells, or source `~/.config/herdr/agentrc.zsh` in existing
shells, for immediate command-based renaming. Agent and tab events use the
plugin registered on the remote server.

### Remote dependency paths

A server started through SSH can have a shorter PATH than an interactive shell.
The rename plugin needs `jq` on **the running server's PATH**, even if the
installer finds it in a login shell. Diagnose through the actual server:

```sh
herdr plugin action invoke herdr-automatic-rename.doctor
herdr plugin log list --plugin herdr-automatic-rename --limit 5
```

The diagnostic should report a jq release and naming decisions. A command can
exit successfully while its output says `jq not found`; check the output too.
Start future servers with the package-manager bin directory on PATH. On mini,
the existing server's PATH included `~/.cargo/bin` but omitted `/usr/local/bin`.
A symlink `~/.cargo/bin/jq -> /usr/local/bin/jq` exposes the existing Homebrew jq
without restarting sessions. This is a machine-specific fix, not something the
portable installer assumes for other hosts.

## Task titles

The agent panel's second row uses `terminal_title_stripped`, which removes a
leading spinner, not a trailing project name. Automatic rename's `TAB_CONTEXT`
controls the tab label separately. In Codex, use `/title` and deselect Project
while keeping Thread selected to remove `| workspace` from the second row.
This is a machine-local Codex preference; it is not part of the Herdr config.
