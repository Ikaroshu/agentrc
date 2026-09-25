# Herdr setup

Portable settings captured from the working macOS setup on 2026-09-24, using
Herdr 0.9.1. This directory is installed separately from the root Codex/Claude
entrypoints. It does not copy workspaces, sessions, SSH machine profiles, plugin
checkouts, logs, caches, or Radar's generated configuration blocks.

## Included settings

- Catppuccin, symbol status indicators, and no new-tab name prompt.
- **Ctrl+B, then E** toggles the file sidebar; one press opens or closes it.
- Unified file/git sidebar on the left, width 32, opened manually, following the
  working directory. File previews open in a pane.
- Radar uses full font logos and its default activity grouping and colours.
- Automatic tab naming stays on; numeric prefixes are off for every scope.

| Plugin | Purpose |
| --- | --- |
| [alexarthurs/herdr-sidebar](https://github.com/alexarthurs/herdr-sidebar) | File explorer, previews, git controls |
| [hhdebb/herdr-radar](https://github.com/hhdebb/herdr-radar) | Agent labels, activity colours and logos |
| [qu8n/herdr-automatic-rename](https://github.com/qu8n/herdr-automatic-rename) | Automatic tab names |

`plugins.tsv` records the installed source commits. The installer requests those
commits rather than a moving branch. The sidebar's upstream build hook downloads
its release binary or builds with Cargo; the source commit alone does not pin
that release asset's bytes. Updating a plugin can change the settings it reads.

## Fresh machine

Use macOS or Linux with zsh. Install [Herdr](https://herdr.dev), Node 18+, jq,
Git, curl, and Python 3.11+ first. The sidebar may need Rust 1.89+ when no prebuilt
binary is available. On macOS with Homebrew:

```sh
brew install herdr node jq python
./herdr/install.sh
```

Run this from a login shell where `herdr`, `node`, `jq`, and `python3` resolve.
The installer writes the four settings files, adds a small zsh hook without
replacing `.zshrc`, installs the plugins, and links `herdr-sidebar` into
`~/.local/bin`. Plugin installation runs the upstream build/setup hooks, including
Radar's font installation. These scripts use the default `~/.config` and
`~/.local/state` locations; do not use them with custom XDG/Herdr config paths.

The installer is for a fresh configuration and refuses existing settings before
writing anything. For an existing installation, merge `config.toml` into the
existing Herdr config, the index settings into
`~/.config/herdr-automatic-rename/config.sh`, `radar.toml` into
`~/.config/herdr/plugins/config/hhdebb.herdr-radar/config.toml`, and `sidebar.json`
into `~/.local/state/herdr/plugins/herdr-sidebar/state.json`. Preserve the other
keys and Radar's `# >>> herdr-radar` / `# <<< herdr-radar` marker blocks. Install
any missing plugins with the source/ref pairs in `plugins.tsv`.

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

Open a new shell (or source `~/.config/herdr/agentrc.zsh`), select the font below,
then launch `herdr`. In a Herdr shell, from this repository, run:

```sh
./herdr/activate.sh
```

This regenerates Radar's blocks with this machine's paths, starts its background
process, and applies the automatic naming settings. Verify `herdr agent list`
shows `tokens` with `group`, a `title_*`, and `sort_key` for a running agent.
Radar's `animator.err` is in `~/.local/state/herdr/plugins/hhdebb.herdr-radar/`.
The script's last `agent list` is a snapshot; a newly launched daemon may publish
its first labels just afterwards. No Herdr server restart is needed.

`herdr-sidebar --preview` is an internal viewer command requiring control data
from the plugin. Open a file through the sidebar instead.

## Fonts: shell symbols and Radar logos together

Radar's bundled JetBrains Mono font lacks the Nerd Font symbols used by a
Powerlevel10k prompt. Use **MesloLGS NF Herdr**, built by adding Radar's 30 icons
to MesloLGS NF. The recipe keeps Meslo's regular, bold, italic, and bold-italic
faces and their original metrics. It is intended for the MesloLGS NF font files
linked by [Powerlevel10k](https://github.com/romkatv/powerlevel10k#fonts).

Install all four original MesloLGS NF files first. With `uv` installed, on macOS:

```sh
radar_root=$(jq -r '.[] | select(.plugin_id == "hhdebb.herdr-radar") | .plugin_root' ~/.config/herdr/plugins.json)
uv run --with fonttools python herdr/build_font.py \
  "$HOME/Library/Fonts" \
  "$radar_root/dist/HerdrAgentIconsMax-Regular.ttf" \
  "$HOME/Library/Fonts"
```

On Linux, pass the directory containing the original Meslo fonts and use
`~/.local/share/fonts` as the output directory, then run `fc-cache -f`.
FontTools is needed only for this build. Generated fonts and third-party font
binaries are not tracked here. Originals are left intact.

In iTerm, select **MesloLGS NF Herdr** under **Settings → Profiles → Text**,
including the separate Non-ASCII font if enabled. Select the same family in other
terminals. The font belongs on the machine rendering the terminal, even when
Herdr runs on an SSH host. A remote host does not need its terminal font changed.

For terminals where full logos are unnecessary, set `variant = "text"` in Radar's
own config instead; stop Radar with its `state-stop` action, then activate again.

## Remote hosts and Node

Clone this repository on the remote machine and run the same setup there.
Herdr's `--machine` forwarding supports plugin actions, not plugin installation.
Install through SSH or a remote shell.

An existing Herdr server may lack NVM's Node directory on its inherited PATH.
Run `activate.sh` from a login shell with Node available; it starts Radar directly
with that Node. For a new server, launch Herdr from a shell with both Node and
Herdr on PATH. This package does not change the environment of an already-running
server, stop sessions, or configure automatic restarts. If that server later loses
Radar, rerun `activate.sh` from the login shell.
