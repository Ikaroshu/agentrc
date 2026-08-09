#!/usr/bin/env python3

import subprocess
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MERGE_SCRIPT = ROOT_DIR / "scripts" / "merge-codex-config.py"


def write_tmp(directory: Path, name: str, content: str) -> Path:
    path = directory / name
    path.write_text(content)
    return path


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        remote = write_tmp(
            tmp_dir,
            "remote.toml",
            '''
model = "old-model"
personality = "remote"
notify = ["/machine/notifier", "turn-ended"]
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true

[projects."/remote/project"]
trust_level = "trusted"

[notice.model_migrations]
"old-model" = "new-model"

[plugins."remote-only@example"]
enabled = true

[[skills.config]]
path = "/remote/skill/SKILL.md"
enabled = false

[features]
memories = false
'''.lstrip(),
        )
        repo = write_tmp(
            tmp_dir,
            "repo.toml",
            '''
model = "gpt-5.4"
personality = "pragmatic"
default_permissions = "workspace-customized"

[permissions.workspace-customized]
extends = ":workspace"

[permissions.workspace-customized.filesystem]
"~/.cache/uv" = "write"
"~/Projects/agentrc/.git" = "write"
"~/Projects/Portseer/.git" = "write"

[permissions.workspace-customized.filesystem.":workspace_roots"]
".git" = "write"

[permissions.workspace-customized.network]
enabled = true

[projects."/repo/project"]
trust_level = "trusted"

[plugins."github@openai-curated"]
enabled = true

[marketplaces.openai-bundled]
source = "/Users/shu/.codex/.tmp/bundled-marketplaces/openai-bundled"

[[skills.config]]
path = "/Users/shu/.codex/skills/doc/SKILL.md"
enabled = false

[features]
memories = true
'''.lstrip(),
        )

        result = subprocess.run(
            ["python3", str(MERGE_SCRIPT), str(remote), str(repo)],
            check=True,
            text=True,
            capture_output=True,
        )

    merged = result.stdout

    assert 'model = "gpt-5.4"' in merged
    assert 'personality = "pragmatic"' in merged
    assert 'notify = ["/machine/notifier", "turn-ended"]' in merged
    assert 'default_permissions = "workspace-customized"' in merged
    assert 'sandbox_mode = "workspace-write"' not in merged
    assert "[sandbox_workspace_write]" not in merged
    assert "[permissions.workspace-customized]" in merged
    assert '"~/.cache/uv" = "write"' in merged
    assert '"~/Projects/agentrc/.git" = "write"' in merged
    assert '"~/Projects/Portseer/.git" = "write"' in merged
    assert '[permissions.workspace-customized.filesystem.":workspace_roots"]' in merged
    assert '".git" = "write"' in merged
    assert '[plugins."github@openai-curated"]' in merged
    assert '[plugins."remote-only@example"]' in merged
    assert '[projects."/remote/project"]' in merged
    assert '[projects."/repo/project"]' not in merged
    assert '[notice.model_migrations]' in merged
    assert '/remote/skill/SKILL.md' in merged
    assert '/Users/shu/.codex/skills/doc/SKILL.md' not in merged
    assert '[marketplaces.openai-bundled]' not in merged
    assert "memories = true" in merged
    assert "enabled = true" in merged


if __name__ == "__main__":
    main()
