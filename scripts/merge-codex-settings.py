"""Merge Nix-owned Codex defaults without replacing runtime TOML settings."""

import json
import os
from pathlib import Path
import sys
import tempfile

import tomlkit


def merge_settings(target, settings):
    document = tomlkit.parse(target.read_text()) if target.exists() else tomlkit.document()
    for key, value in settings.items():
        if key == "mcp_servers":
            servers = document.setdefault(key, tomlkit.table())
            for name, server in value.items():
                servers[name] = server
        else:
            document[key] = value
    contents = tomlkit.dumps(document)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Atomic replacement also handles an old Nix store symlink.
    fd, temporary = tempfile.mkstemp(dir=target.parent, prefix=target.name + ".")
    try:
        with os.fdopen(fd, "w") as output:
            output.write(contents)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    merge_settings(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
