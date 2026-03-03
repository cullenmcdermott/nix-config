#!/usr/bin/env python3
"""Assess complexity of git changes and recommend reviewer allocation.

Analyzes git diff output to determine:
- Change size (lines added/removed, files changed)
- Whether sensitive areas are touched (auth, crypto, infra)
- Recommended complexity level and reviewer personas

Usage:
    uv run scripts/assess_complexity.py                    # staged changes
    uv run scripts/assess_complexity.py --diff-args HEAD~1 # last commit
    uv run scripts/assess_complexity.py --diff-args main   # vs main branch
"""

import argparse
import json
import re
import shlex
import subprocess
import sys

SENSITIVE_PATTERNS = [
    r"\bauth\b",
    r"crypto",
    r"secret",
    r"password",
    r"\btoken\b",
    r"\bkey\b",
    r"credential",
    r"permission",
    r"\brbac\b",
    r"\bacl\b",
    r"oauth",
    r"\bjwt\b",
    r"\bsession\b",
    r"\bcookie\b",
    r"\bcsrf\b",
    r"\bcors\b",
    r"\bssl\b",
    r"\btls\b",
    r"\bcert\b",
    r"encrypt",
    r"decrypt",
    r"\bhash\b",
    r"\bsign(ing|ed|ature)?\b",
    r"\bverify\b",
    r"infrastructure",
    r"deploy",
    r"ci[/-]cd",
    r"pipeline",
    r"terraform",
    r"helm",
    r"k8s",
    r"kubernetes",
    r"docker",
    r"\.env",
    r"migration",
]

_SENSITIVE_RE = re.compile("|".join(SENSITIVE_PATTERNS), re.IGNORECASE)

REVIEWER_SETS = {
    "small": ["reviewer-architect", "reviewer-stylist"],
    "medium": ["reviewer-architect", "reviewer-stylist", "reviewer-tester"],
    "large": [
        "reviewer-architect",
        "reviewer-stylist",
        "reviewer-tester",
        "reviewer-perf",
        "external-reviewer",
    ],
    "critical": [
        "reviewer-architect",
        "reviewer-stylist",
        "reviewer-tester",
        "reviewer-perf",
        "reviewer-security",
        "reviewer-newcomer",
        "external-reviewer",
    ],
}


_SAFE_ARG_RE = re.compile(r"^[a-zA-Z0-9_.~^/:@{}\-]+$")


def _parse_diff_args(diff_args: str) -> list[str]:
    """Parse and validate diff arguments to prevent git flag injection."""
    tokens = shlex.split(diff_args)
    for token in tokens:
        if token == "--" or _SAFE_ARG_RE.match(token):
            continue
        raise ValueError(f"Unsafe diff argument: {token}")
    return tokens


def get_diff_stats(diff_args: str | None) -> tuple[int, list[str], str]:
    """Get diff statistics: lines changed, files changed, raw diff.

    Runs a single git diff call and derives stats from the raw output.
    """
    cmd = ["git", "diff"]
    if diff_args:
        cmd.extend(_parse_diff_args(diff_args))
    else:
        cmd.append("--cached")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        raw_diff = result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return 0, [], ""

    files = []
    additions = 0
    deletions = 0
    for line in raw_diff.split("\n"):
        if line.startswith("diff --git"):
            # Extract filename from "diff --git a/path b/path"
            parts = line.split(" b/", 1)
            if len(parts) == 2:
                files.append(parts[1])
        elif line.startswith("+") and not line.startswith("+++"):
            additions += 1
        elif line.startswith("-") and not line.startswith("---"):
            deletions += 1

    return additions + deletions, files, raw_diff


def check_sensitivity(files: list[str], raw_diff: str) -> bool:
    """Check if changes touch sensitive areas."""
    combined = " ".join(files) + "\n" + raw_diff
    return bool(_SENSITIVE_RE.search(combined))


def assess(diff_args: str | None) -> dict:
    """Run full complexity assessment."""
    total_lines, files, raw_diff = get_diff_stats(diff_args)
    num_files = len(files)
    touches_sensitive = check_sensitivity(files, raw_diff)

    # Determine complexity level
    if touches_sensitive or total_lines >= 500:
        complexity = "critical"
    elif total_lines >= 200 or num_files > 5:
        complexity = "large"
    elif total_lines >= 50 or num_files > 2:
        complexity = "medium"
    else:
        complexity = "small"

    return {
        "complexity": complexity,
        "lines_changed": total_lines,
        "files_changed": num_files,
        "files": files,
        "touches_sensitive": touches_sensitive,
        "recommended_reviewers": REVIEWER_SETS[complexity],
        "summary": f"{complexity.title()} change: {total_lines} lines across {num_files} files"
        + (" (touches sensitive areas)" if touches_sensitive else ""),
    }


def main():
    parser = argparse.ArgumentParser(description="Assess git diff complexity")
    parser.add_argument(
        "--diff-args",
        default=None,
        help="Arguments to pass to git diff (e.g., 'HEAD~1', 'main')",
    )
    args = parser.parse_args()

    result = assess(args.diff_args)
    json.dump(result, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
