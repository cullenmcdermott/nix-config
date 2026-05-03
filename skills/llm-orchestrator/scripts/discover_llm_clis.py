#!/usr/bin/env python3
"""Discover installed and authenticated LLM CLI tools.

Checks for: claude, agent (Cursor CLI), llm, gemini, aider.
Returns JSON with availability status.
"""

import json
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed


KNOWN_CLIS = {
    "claude": {
        "command": "claude",
        "version_flag": "--version",
        "description": "Claude Code CLI",
    },
    "cursor-agent": {
        "command": "cursor-agent",
        "version_flag": "--version",
        "description": "Cursor CLI",
    },
    "llm": {
        "command": "llm",
        "version_flag": "--version",
        "description": "Simon Willison's LLM CLI",
    },
    "gemini": {
        "command": "gemini",
        "version_flag": "--version",
        "description": "Google Gemini CLI",
    },
    "aider": {
        "command": "aider",
        "version_flag": "--version",
        "description": "Aider AI pair programming",
    },
}


def check_cli(name: str, info: dict) -> dict:
    """Check if a CLI tool is installed and get its version."""
    path = shutil.which(info["command"])
    if not path:
        return {"installed": False}

    result = {"installed": True, "path": path}

    try:
        proc = subprocess.run(
            [info["command"], info["version_flag"]],
            capture_output=True,
            text=True,
            timeout=10,
        )
        version = proc.stdout.strip().split("\n")[0] if proc.stdout else None
        if version:
            result["version"] = version
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    return result


def main():
    available = []
    unavailable = []
    details = {}

    with ThreadPoolExecutor(max_workers=len(KNOWN_CLIS)) as executor:
        futures = {
            executor.submit(check_cli, name, info): name
            for name, info in KNOWN_CLIS.items()
        }
        for future in as_completed(futures):
            name = futures[future]
            result = future.result()
            details[name] = result
            if result["installed"]:
                available.append(name)
            else:
                unavailable.append(name)

    output = {
        "available": available,
        "unavailable": unavailable,
        "details": details,
    }

    json.dump(output, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
