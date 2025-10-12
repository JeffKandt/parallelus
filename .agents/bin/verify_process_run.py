#!/usr/bin/env python3
"""Post-run verification for the agent process smoke test."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
import sys
from typing import List

def run(cmd: List[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, check=check, text=True, capture_output=True)


def fail(message: str) -> None:
    print(f"verify_process_run: {message}", file=sys.stderr)
    sys.exit(1)



def assert_session(repo: Path) -> None:
    sessions_dir = repo / "sessions"
    if not sessions_dir.exists():
        fail("sessions directory missing")
    session_dirs = sorted(sessions_dir.glob("*"), key=lambda p: p.stat().st_mtime)
    if not session_dirs:
        fail("no session directory created")
    latest = session_dirs[-1]
    summary = latest / "summary.md"
    meta = latest / "meta.json"
    if not summary.exists():
        fail(f"session summary not found in {latest.relative_to(repo)}")
    if not meta.exists():
        fail(f"session meta.json missing in {latest.relative_to(repo)}")
    json.loads(meta.read_text())  # ensure valid JSON


def assert_readme(repo: Path) -> None:
    readme = repo / "README.md"
    if "Smoke test updated" not in readme.read_text():
        fail("README does not include smoke test note")


def assert_git_clean(repo: Path) -> None:
    status = run(["git", "status", "--porcelain"], cwd=repo)
    if status.stdout.strip():
        fail("git status not clean after run")


def assert_notebooks_removed(repo: Path) -> None:
    plans = list((repo / "docs" / "plans").glob("feature-*.md"))
    progresses = list((repo / "docs" / "progress").glob("feature-*.md"))
    if plans or progresses:
        fail(
            "feature notebooks still present after merge: "
            + ", ".join(str(p.relative_to(repo)) for p in plans + progresses)
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="Path to the sandbox repository")
    parser.add_argument("--log", help="Codex CLI log file (optional)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    repo = Path(args.repo).resolve()
    if not repo.exists():
        fail(f"repo path {repo} does not exist")

    assert_readme(repo)
    assert_session(repo)
    assert_git_clean(repo)
    assert_notebooks_removed(repo)

    print("verify_process_run: success")


if __name__ == "__main__":
    main()
