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
approval_policy = "never"
approvals_reviewer = "machine-reviewer"
default_permissions = "machine-policy"
sandbox_mode = "workspace-write"
web_search = "cached"

[sandbox_workspace_write]
network_access = true

[permissions.machine-policy]
extends = ":workspace"

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

[tui]
status_line = ["model"]
'''.lstrip(),
        )
        repo = write_tmp(
            tmp_dir,
            "repo.toml",
            '''
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
personality = "pragmatic"

[tui]
status_line = ["model-with-reasoning", "current-dir"]

[desktop]
mac-menu-bar-enabled = false
'''.lstrip(),
        )

        result = subprocess.run(
            ["python3", str(MERGE_SCRIPT), str(remote), str(repo)],
            check=True,
            text=True,
            capture_output=True,
        )

    merged = result.stdout

    assert 'model = "gpt-5.6-sol"' in merged
    assert 'model_reasoning_effort = "xhigh"' in merged
    assert 'personality = "pragmatic"' in merged
    assert 'notify = ["/machine/notifier", "turn-ended"]' in merged
    assert 'approval_policy = "never"' in merged
    assert 'approvals_reviewer = "machine-reviewer"' in merged
    assert 'default_permissions = "machine-policy"' in merged
    assert 'sandbox_mode = "workspace-write"' in merged
    assert 'web_search = "cached"' in merged
    assert "[sandbox_workspace_write]" in merged
    assert "[permissions.machine-policy]" in merged
    assert '[projects."/remote/project"]' in merged
    assert "[notice.model_migrations]" in merged
    assert '[plugins."remote-only@example"]' in merged
    assert "/remote/skill/SKILL.md" in merged
    assert "memories = false" in merged
    assert 'status_line = ["model-with-reasoning", "current-dir"]' in merged
    assert 'status_line = ["model"]' not in merged
    assert "[desktop]" in merged
    assert "mac-menu-bar-enabled = false" in merged


if __name__ == "__main__":
    main()
