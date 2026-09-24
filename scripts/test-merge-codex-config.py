#!/usr/bin/env python3

import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MERGE_SCRIPT = ROOT_DIR / "scripts" / "merge-codex-config.py"


def run_merge(directory: Path, machine_text: str, repo_text: str) -> str:
    machine = directory / "machine.toml"
    repo = directory / "repo.toml"
    machine.write_text(machine_text)
    repo.write_text(repo_text)
    return subprocess.run(
        [sys.executable, str(MERGE_SCRIPT), str(machine), str(repo)],
        check=True,
        text=True,
        capture_output=True,
    ).stdout


def main() -> None:
    machine_text = r'''
model = "old-model"
personality = "remote"
notify = [
  "/machine/notifier",
  "turn-ended",
]
approval_policy = "never"
approvals_reviewer = "machine-reviewer"
default_permissions = "machine-policy"
sandbox_mode = "workspace-write"
web_search = "cached"

[sandbox_workspace_write]
network_access = true
writable_roots = ["/machine/cache"]

[permissions.machine-policy]
extends = ":workspace"

[projects."/remote/project"]
trust_level = "trusted"

[notice.model_migrations]
"old-model" = "new-model"

[marketplaces."remote.marketplace"]
source = { path = "/remote/marketplace" }

[plugins."remote-only@example"]
enabled = true

[[skills.config]]
path = "/remote/skill/SKILL.md"
enabled = false

[[skills.config]]
path = "/remote/second/SKILL.md"
enabled = true

[features]
memories = false

[tui]
status_line = ["model"]
notifications = false

["desktop"] # Shared table with machine-only settings
mac-menu-bar-enabled = true
ambient-suggestions-enabled = false
appearanceDarkChromeTheme = { accent = "#1f6feb", fonts = {}, semanticColors = { skill = "#bc8cff" } }

[local_values]
"quoted.key" = "quotes: \" slash: \\ tab: \t newline: \n controls: \u0000\u001f\u007f emoji: 😀"
multiline = """first
second"""
integer = 42
float = 1.25
negative_zero = -0.0
infinity = inf
negative_infinity = -inf
local_date = 2026-09-05
local_time = 12:30:45.123456
local_datetime = 2026-09-05T12:30:45
utc_datetime = 2026-09-05T12:30:45Z
offset_datetime = 2026-09-05T12:30:45-04:00
nested_arrays = [[1, 2], [3]]
inline_tables = [{ key = "value", nested = { enabled = true } }, { key = "second", nested = { enabled = false } }]
'''
    repo_text = '''
model = "gpt-6-astra"
model_reasoning_effort = "high"
personality = "pragmatic"
tui.status_line = ["model-with-reasoning", "current-dir"]
desktop.mac-menu-bar-enabled = false
desktop.appearanceDarkChromeTheme.accent = "#ffffff"

[projects."/remote/project"]
trust_level = "untrusted"

[projects."/repo/project"]
trust_level = "trusted"

[notice.model_migrations]
"old-model" = "repo-model"

[marketplaces."remote.marketplace"]
source = { path = "/repo/marketplace" }

[[skills.config]]
path = "/repo/skill/SKILL.md"
enabled = true
'''
    expected = tomllib.loads(machine_text)
    expected["model"] = "gpt-6-astra"
    expected["model_reasoning_effort"] = "high"
    expected["personality"] = "pragmatic"
    expected["tui"]["status_line"] = ["model-with-reasoning", "current-dir"]
    expected["desktop"]["mac-menu-bar-enabled"] = False
    expected["desktop"]["appearanceDarkChromeTheme"]["accent"] = "#ffffff"

    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        merged = run_merge(directory, machine_text, repo_text)
        assert tomllib.loads(merged) == expected
        # The app-server skill editor requires this representation to remove/add selectors.
        assert merged.count("[[skills.config]]") == 2
        assert "config = [" not in merged
        assert run_merge(directory, merged, repo_text) == merged
        assert run_merge(directory, merged, "") == merged
        assert tomllib.loads(run_merge(directory, "", repo_text)) == tomllib.loads('''
model = "gpt-6-astra"
model_reasoning_effort = "high"
personality = "pragmatic"
tui.status_line = ["model-with-reasoning", "current-dir"]
desktop.mac-menu-bar-enabled = false
desktop.appearanceDarkChromeTheme.accent = "#ffffff"
[skills]
''')
        baseline = (ROOT_DIR / "codex/config.toml").read_text()
        installed = tomllib.loads(run_merge(directory, machine_text, baseline))
        expected["desktop"]["appearanceDarkChromeTheme"]["accent"] = "#1f6feb"
        expected["tui"] = tomllib.loads(machine_text)["tui"]
        assert installed["tui"] == expected["tui"], "Deployment must preserve machine-local TUI preferences"
        assert "tui" not in tomllib.loads(run_merge(directory, "", baseline))
        assert installed == expected
        # Shared settings can switch between inline and ordinary table syntax.
        assert tomllib.loads(run_merge(directory, 'desktop = { keep = false, replace = 1 }',
                                       '[desktop]\nreplace = 2')) == {"desktop": {"keep": False, "replace": 2}}
        assert tomllib.loads(run_merge(directory, 'setting = 1', '[setting]\nkey = true')) == {"setting": {"key": True}}
        assert tomllib.loads(run_merge(directory, '[setting]\nkey = true', 'setting = 1')) == {"setting": 1}
        nan = tomllib.loads(run_merge(directory, "value = nan", ""))["value"]
        assert nan != nan
    print("Config merge tests passed (nested preservation, overrides, machine paths, TOML values, and stable reruns).")


if __name__ == "__main__":
    main()
