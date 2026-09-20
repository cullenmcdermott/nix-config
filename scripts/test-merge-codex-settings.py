"""Run with the same tomlkit Python environment as the activation script."""

import importlib.util
from pathlib import Path
import tempfile

import tomlkit

spec = importlib.util.spec_from_file_location(
    "merge_codex", Path(__file__).with_name("merge-codex-settings.py")
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / "config.toml"
    settings = {
        "approval_policy": "on-request",
        "approvals_reviewer": "auto_review",
        "sandbox_mode": "workspace-write",
        "mcp_servers": {"shared": {"url": "https://example.test/mcp"}},
    }
    module.merge_settings(target, settings)
    assert tomlkit.parse(target.read_text())["approvals_reviewer"] == "auto_review"
    target.write_text(
        '# runtime comment\nmodel = "chosen-model"\n'
        '[projects."/repo"]\ntrust_level = "trusted"\n'
        '[mcp_servers.private]\ncommand = "private-server"\n'
        '[mcp_servers.shared]\ncommand = "obsolete-transport"\n'
    )
    module.merge_settings(target, settings)
    content = target.read_text()
    parsed = tomlkit.parse(content)
    assert "# runtime comment" in content and parsed["model"] == "chosen-model"
    assert parsed["projects"]["/repo"]["trust_level"] == "trusted"
    assert parsed["mcp_servers"]["private"]["command"] == "private-server"
    assert dict(parsed["mcp_servers"]["shared"]) == settings["mcp_servers"]["shared"]
    module.merge_settings(target, settings)
    assert target.read_text() == content
    assert target.stat().st_mode & 0o777 == 0o600
    target.write_text("invalid [toml")
    try:
        module.merge_settings(target, settings)
    except tomlkit.exceptions.ParseError:
        pass
    else:
        raise AssertionError("Invalid config must fail without overwriting it")
    assert target.read_text() == "invalid [toml"
print("PASS: defaults, preservation, transport replacement, idempotence, mode, invalid TOML")
