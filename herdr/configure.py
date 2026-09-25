#!/usr/bin/env python3

import json
import re
import runpy
import sys
import tomllib
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parent
    home = Path.home()
    merge = sys.argv[1:] == ['--merge']
    files = {
        'config.toml': '.config/herdr/config.toml',
        'automatic-rename.sh': '.config/herdr-automatic-rename/config.sh',
        'sidebar.json': '.local/state/herdr/plugins/herdr-sidebar/state.json',
        'shell.zsh': '.config/herdr/agentrc.zsh',
    }
    link = home / '.local/bin/herdr-sidebar'
    targets = [home / target for target in files.values()] + [link]
    existing = [str(target) for target in targets if target.exists() or target.is_symlink()]
    if existing and not merge:
        raise SystemExit('Fresh setup only; use --merge for existing files:\n' + '\n'.join(existing))
    if link.exists() and not link.is_symlink():
        raise SystemExit(f'Refusing to replace a regular file: {link}')

    toml = runpy.run_path(str(root.parent / 'scripts/merge-codex-config.py'))
    for source, target in files.items():
        destination = home / target
        text = (root / source).read_text()
        if merge and destination.exists():
            current = destination.read_text()
            if source == 'config.toml':
                machine = tomllib.loads(current)
                repo = tomllib.loads(text)
                commands = repo['keys']['command']
                managed_keys = {command['key'] for command in commands}
                repo['keys']['command'] = [
                    command for command in machine.get('keys', {}).get('command', [])
                    if command['key'] not in managed_keys
                ] + commands
                merged = toml['merge_settings'](machine, repo)
                text = '\n'.join(toml['format_table'](merged)).strip() + '\n'
            elif source == 'sidebar.json':
                text = json.dumps({**json.loads(current), **json.loads(text)}, indent=2) + '\n'
            elif source == 'automatic-rename.sh':
                for line in text.splitlines():
                    name = line.split('=', 1)[0]
                    current = re.sub(rf'^{name}=.*\n?', '', current, flags=re.MULTILINE)
                text = current.rstrip() + '\n' + text
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)

    rc = home / '.zshrc'
    text = rc.read_text() if rc.exists() else ''
    line = 'source "$HOME/.config/herdr/agentrc.zsh"'
    if line not in text.splitlines():
        rc.write_text(text.rstrip() + '\n\n' + line + '\n')


if __name__ == '__main__':
    main()
