# Herdr setup

Portable settings captured from the working macOS setup on 2026-09-24, using
Herdr 0.9.1. This directory is installed separately from the root Codex/Claude
entrypoints. It does not copy workspaces, sessions, SSH machine profiles, plugin
checkouts, logs, or caches.

## Included settings

- Catppuccin, symbol status indicators, and no new-tab name prompt.
- **Ctrl+B, then E** toggles the file sidebar; one press opens or closes it.
- Unified file/git sidebar on the left, width 32, opened manually, following the
  working directory. File previews open in a pane.
- Herdr's built-in agent sidebar.
- Automatic tab naming stays on; numeric prefixes are off for every scope.

| Plugin | Purpose |
| --- | --- |
| [alexarthurs/herdr-sidebar](https://github.com/alexarthurs/herdr-sidebar) | File explorer, previews, git controls |
| [qu8n/herdr-automatic-rename](https://github.com/qu8n/herdr-automatic-rename) | Automatic tab names |

`plugins.tsv` records the installed source commits. The installer requests those
commits rather than a moving branch. The sidebar's upstream build hook downloads
its release binary or builds with Cargo; the source commit alone does not pin
that release asset's bytes. Updating a plugin can change the settings it reads.

## Fresh machine

Use macOS or Linux with zsh. Install [Herdr](https://herdr.dev), jq, Git, curl,
and Python 3.11+ first. The sidebar may need Rust 1.89+ when no prebuilt binary
is available. On macOS with Homebrew:

```sh
brew install herdr jq python
./herdr/install.sh
```

Run this from a login shell where `herdr`, `jq`, and `python3` resolve. The
installer writes the settings files, adds a small zsh hook without replacing
`.zshrc`, installs the plugins, and links `herdr-sidebar` into `~/.local/bin`.
Plugin installation runs the upstream build hooks. These scripts use the default
`~/.config` and `~/.local/state` locations; do not use them with custom XDG/Herdr
config paths.

The installer is for a fresh configuration and refuses existing settings before
writing anything. For an existing installation, merge `config.toml` into the
existing Herdr config, the index settings into
`~/.config/herdr-automatic-rename/config.sh`, and `sidebar.json` into
`~/.local/state/herdr/plugins/herdr-sidebar/state.json`, preserving other keys.
Install any missing plugins with the source/ref pairs in `plugins.tsv`.

If installation stops during a plugin download/build, fix the reported cause
and rerun that `herdr plugin install SOURCE --ref COMMIT --yes` command and the
remaining plugin commands from `plugins.tsv`. The already-written configuration
is retained; the fresh-machine installer intentionally does not overwrite it.
Complete the sidebar link using its `plugin_root` from
`~/.config/herdr/plugins.json`:

```sh
sidebar_root=$(jq -r '.[] | select(.plugin_id == "herdr-sidebar") | .plugin_root' ~/.config/herdr/plugins.json)
mkdir -p ~/.local/bin
ln -s "$sidebar_root/target/release/herdr-sidebar" ~/.local/bin/herdr-sidebar
```

Open a new shell (or source `~/.config/herdr/agentrc.zsh`), select a Nerd Font,
then launch `herdr`. In a Herdr shell, from this repository, run:

```sh
./herdr/activate.sh
```

This reloads Herdr's settings and applies automatic naming without number
prefixes. No Herdr server restart is needed. `herdr-sidebar --preview` is an
internal viewer command requiring control data from the plugin; open a file
through the sidebar instead.

## Fonts

Use **MesloLGS NF**, including all four faces, from
[Powerlevel10k's font instructions](https://github.com/romkatv/powerlevel10k#fonts).
It covers shell prompt symbols and the file sidebar's icons. In iTerm, select it
under **Settings → Profiles → Text**, including the separate Non-ASCII font if
enabled. The previously installed **MesloLGS NF Herdr** also remains usable;
its extra icons are harmless. No custom font build or Node runtime is required.

The font belongs on the machine rendering the terminal, even when Herdr runs on
an SSH host. A remote host does not need its terminal font changed.

## Remote hosts

Clone this repository on the remote machine and run the same setup there.
Herdr's `--machine` forwarding supports plugin actions, not plugin installation.
Install through SSH or a remote shell.
