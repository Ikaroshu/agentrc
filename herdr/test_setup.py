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
    root.mkdir(parents=True)
    executable = root / 'target/release/herdr-sidebar'
    executable.parent.mkdir(parents=True)
    executable.touch()
    registry = home / '.config/herdr/plugins.json'
    entries = json.loads(registry.read_text()) if registry.exists() else []
    entries.append({'plugin_id': plugin, 'plugin_root': str(root)})
    registry.write_text(json.dumps(entries))
    (root / 'automatic-rename.sh').write_text('exit 0\\n')
''')
        mock.chmod(0o755)
        env = dict(os.environ, HOME=str(home), PATH=f'{bin_dir}:{os.environ["PATH"]}', HERDR_TEST_LOG=str(log))
        subprocess.run(['bash', str(ROOT / 'install.sh')], env=env, check=True, capture_output=True)
        config = tomllib.loads((home / '.config/herdr/config.toml').read_text())
        assert config['keys']['command'][0]['key'] == 'prefix+e'
        assert config['theme']['name'] == 'catppuccin'
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

        subprocess.run(['bash', str(ROOT / 'activate.sh')], env=env, check=True, capture_output=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert all(call[0] == 'herdr' for call in calls)
        assert [call for call in calls if call[1:3] == ['server', 'reload-config']]
        assert calls[-1] == ['herdr', 'agent', 'list']

        if real_herdr:
            subprocess.run([real_herdr, 'config', 'check'],
                           env=dict(os.environ, HERDR_CONFIG_PATH=str(ROOT / 'config.toml')), check=True)
    print('Herdr setup checks passed')


if __name__ == '__main__':
    main()
