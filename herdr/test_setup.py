#!/usr/bin/env python3

import json
import os
import shutil
import subprocess
import tempfile
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def main() -> None:
    real_herdr = shutil.which('herdr')
    with tempfile.TemporaryDirectory(prefix='agentrc-herdr-') as scratch:
        base = Path(scratch)
        home = base / 'home'
        home.mkdir()
        (home / '.zshrc').write_text('export EXISTING_SETTING=keep\n')
        bin_dir = base / 'bin'
        bin_dir.mkdir()
        log = base / 'commands.jsonl'
        mock = bin_dir / 'herdr'
        mock.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
home = Path.home()
with Path(os.environ['HERDR_TEST_LOG']).open('a') as log:
    log.write(json.dumps([Path(sys.argv[0]).name, *args]) + '\\n')
if args[:2] == ['plugin', 'install']:
    plugin = {'alexarthurs/herdr-sidebar/plugins/herdr-sidebar': 'herdr-sidebar',
              'qu8n/herdr-automatic-rename': 'herdr-automatic-rename'}[args[2]]
    root = home / '.config/herdr/plugins/github' / plugin
    root.mkdir(parents=True, exist_ok=True)
    executable = root / 'target/release/herdr-sidebar'
    executable.parent.mkdir(parents=True, exist_ok=True)
    executable.touch()
    registry = home / '.config/herdr/plugins.json'
    entries = json.loads(registry.read_text()) if registry.exists() else []
    entries = [entry for entry in entries if entry['plugin_id'] != plugin]
    entries.append({'plugin_id': plugin, 'plugin_root': str(root)})
    registry.write_text(json.dumps(entries))
    (root / 'automatic-rename.sh').write_text('exit 0\\n')
''')
        mock.chmod(0o755)
        env = dict(os.environ, HOME=str(home), PATH=f'{bin_dir}:{os.environ["PATH"]}', HERDR_TEST_LOG=str(log))
        subprocess.run(['bash', str(ROOT / 'install.sh')], env=env, check=True, capture_output=True)
        config = tomllib.loads((home / '.config/herdr/config.toml').read_text())
        assert config['keys']['command'][0]['key'] == 'prefix+e'
        assert config['keys']['prefix'] == 'ctrl+\\'
        assert config['theme']['name'] == 'one-dark'
        assert config['ui']['sidebar_width'] == 36
        assert (home / '.zshrc').read_text().startswith('export EXISTING_SETTING=keep\n')
        assert (home / '.local/bin/herdr-sidebar').resolve().is_file()
        sidebar = json.loads((home / '.local/state/herdr/plugins/herdr-sidebar/state.json').read_text())
        assert sidebar['strict_toggle'] and not sidebar['auto_open']
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        expected = [['herdr', 'plugin', 'install', source, '--ref', revision, '--yes']
                    for _, source, revision in (line.split() for line in (ROOT / 'plugins.tsv').read_text().splitlines())]
        assert [call for call in calls if call[1:3] == ['plugin', 'install']] == expected

        before = {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()}
        previous_log = log.read_text()
        result = subprocess.run(['bash', str(ROOT / 'install.sh')], env=env, capture_output=True, text=True)
        assert result.returncode != 0 and 'Fresh setup only' in result.stderr
        assert before == {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()}
        assert log.read_text() == previous_log

        # Merge updates existing settings without losing unrelated local state.
        config_path = home / '.config/herdr/config.toml'
        config_path.write_text(config_path.read_text() + '\n[terminal]\ndefault_shell = "/bin/zsh"\n'
                               + '\n[[keys.command]]\nkey = "prefix+t"\ntype = "shell"\ncommand = "date"\n')
        rename_path = home / '.config/herdr-automatic-rename/config.sh'
        rename_path.write_text('MAX_TITLE_LEN=60\nAUTO_INDEX=1\nTAB_CONTEXT=0\n')
        sidebar_path = home / '.local/state/herdr/plugins/herdr-sidebar/state.json'
        sidebar_path.write_text(json.dumps({'view': 'git', 'sidebar_width': 10}))
        subprocess.run(['bash', str(ROOT / 'install.sh'), '--merge'], env=env, check=True, capture_output=True)
        merged = tomllib.loads(config_path.read_text())
        assert merged['terminal']['default_shell'] == '/bin/zsh'
        assert {command['key'] for command in merged['keys']['command']} == {'prefix+e', 'prefix+t'}
        assert merged['ui']['sidebar_width'] == 36
        assert 'MAX_TITLE_LEN=60' in rename_path.read_text()
        assert 'AUTO_INDEX=1' not in rename_path.read_text() and 'TAB_CONTEXT=0' not in rename_path.read_text()
        assert json.loads(sidebar_path.read_text())['view'] == 'git'
        assert json.loads(sidebar_path.read_text())['sidebar_width'] == 32
        assert (home / '.zshrc').read_text().count('source "$HOME/.config/herdr/agentrc.zsh"') == 1
        merged_files = {str(path): path.read_bytes() for path in
                        [config_path, rename_path, sidebar_path, home / '.zshrc']}
        subprocess.run(['bash', str(ROOT / 'install.sh'), '--merge'], env=env, check=True, capture_output=True)
        assert merged_files == {path: Path(path).read_bytes() for path in merged_files}

        subprocess.run(['bash', str(ROOT / 'activate.sh')], env=env, check=True, capture_output=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert all(call[0] == 'herdr' for call in calls)
        assert [call for call in calls if call[1:3] == ['server', 'reload-config']]
        assert calls[-1] == ['herdr', 'agent', 'list']

        # Exercise the SSH bundle and remote installer with a separate home.
        remote_home = base / 'remote'
        remote_home.mkdir()
        (remote_home / '.zshrc').write_text('export REMOTE_SETTING=keep\n')
        ssh = bin_dir / 'ssh'
        ssh.write_text('''#!/usr/bin/env python3
import os, subprocess, sys
assert sys.argv[1] == 'test'
command = sys.argv[2].replace('zsh -lc ', 'zsh -fc ')
subprocess.run(['bash', '-c', command], env=dict(os.environ, HOME=os.environ['HERDR_TEST_REMOTE']), check=True)
''')
        ssh.chmod(0o755)
        scp = bin_dir / 'scp'
        scp.write_text('''#!/usr/bin/env python3
import os, shutil, sys
from pathlib import Path
assert sys.argv[1] == '-q'
assert sys.argv[-1].startswith('test:~/')
destination = Path(os.environ['HERDR_TEST_REMOTE']) / sys.argv[-1][7:]
for source in sys.argv[2:-1]:
    shutil.copy(source, destination)
''')
        scp.chmod(0o755)
        subprocess.run(['bash', str(ROOT / 'sync-remote.sh'), 'test'],
                       env=dict(env, HERDR_TEST_REMOTE=str(remote_home)), check=True, capture_output=True)
        remote_config = tomllib.loads((remote_home / '.config/herdr/config.toml').read_text())
        assert remote_config == tomllib.loads((ROOT / 'config.toml').read_text())
        assert (remote_home / '.zshrc').read_text().startswith('export REMOTE_SETTING=keep\n')
        assert (remote_home / '.local/bin/herdr-sidebar').resolve().is_file()
        assert {entry['plugin_id'] for entry in json.loads(
            (remote_home / '.config/herdr/plugins.json').read_text())} == {'herdr-sidebar', 'herdr-automatic-rename'}

        if real_herdr:
            subprocess.run([real_herdr, 'config', 'check'],
                           env=dict(os.environ, HERDR_CONFIG_PATH=str(ROOT / 'config.toml')), check=True)
    print('Herdr setup checks passed')


if __name__ == '__main__':
    main()
