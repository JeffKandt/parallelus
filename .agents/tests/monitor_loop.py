#!/usr/bin/env python3
"""Smoke tests for `.agents/bin/agents-monitor-loop.sh` guardrails.

The monitor loop script exits early when either the heartbeat threshold or
runtime threshold is exceeded, or when no subagents are running. These tests
simulate the `subagent_manager.sh status` output so we can assert the expected
markers (`!` and `^`) and exit messages without requiring a real registry.
"""

from __future__ import annotations

import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from textwrap import dedent


SCRIPT_UNDER_TEST = Path(__file__).resolve().parents[1] / "bin" / "agents-monitor-loop.sh"

HEADER = (
    "ID                       Type       Slug                      Status           Deliverables Run Time  Log Age   Handle         Last Log (UTC)"
)
SEPARATOR = "-" * len(HEADER)


def _write_stub(repo_root: Path, scenario: str) -> None:
    """Create a stubbed `subagent_manager.sh` matching the monitor loop expectations."""

    stub_path = repo_root / ".agents" / "bin" / "subagent_manager.sh"
    stub_path.parent.mkdir(parents=True, exist_ok=True)

    if scenario == "runtime":
        body = f"""
            #!/usr/bin/env bash
            set -euo pipefail
            cat <<'EOF'
{HEADER}
{SEPARATOR}
20251009-000000-monitor worktree   monitor-loop-test         running          pending      11:05     00:20     -              2025-10-09 19:00:00
EOF
        """
    elif scenario == "heartbeat":
        body = f"""
            #!/usr/bin/env bash
            set -euo pipefail
            cat <<'EOF'
{HEADER}
{SEPARATOR}
20251009-000001-monitor worktree   monitor-loop-test         running          pending      02:15     04:10     -              2025-10-09 19:05:00
EOF
        """
    elif scenario == "none":
        body = """
            #!/usr/bin/env bash
            set -euo pipefail
            echo "No matching subagents."
        """
    elif scenario == "multi":
        body = f"""
            #!/usr/bin/env bash
            set -euo pipefail
            cat <<'EOF'
{HEADER}
{SEPARATOR}
20251009-000010-monitor worktree   monitor-loop-alpha       running          pending      01:15     00:45     %0/@0          2025-10-09 19:10:00
20251009-000011-monitor worktree   monitor-loop-beta        running          pending      00:25     00:30     %1/@0          2025-10-09 19:10:10
20251009-000012-monitor worktree   monitor-loop-gamma       cleaned          harvested    00:00     -         -              -
EOF
        """
    elif scenario == "stale":
        body = f"""
            #!/usr/bin/env bash
            set -euo pipefail
            cat <<'EOF'
{HEADER}
{SEPARATOR}
20251009-000020-monitor worktree   monitor-loop-stale       running          pending      00:00     -         -              -
EOF
        """
    else:
        raise ValueError(f"unknown scenario: {scenario}")

    stub_path.write_text(dedent(body).strip() + "\n", encoding="utf-8")
    mode = os.stat(stub_path).st_mode
    os.chmod(stub_path, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _setup_repo(scenario: str) -> Path:
    tmp_dir = Path(tempfile.mkdtemp(prefix=f"monitor-loop-{scenario}-"))
    script_dest = tmp_dir / ".agents" / "bin"
    script_dest.mkdir(parents=True, exist_ok=True)

    shutil.copy2(SCRIPT_UNDER_TEST, script_dest / "agents-monitor-loop.sh")
    mode = os.stat(script_dest / "agents-monitor-loop.sh").st_mode
    os.chmod(script_dest / "agents-monitor-loop.sh", mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    _write_stub(tmp_dir, scenario)
    subprocess.run(["git", "init", "-q"], cwd=tmp_dir, check=True)
    return tmp_dir


def _run_monitor(repo_root: Path, *extra_args: str) -> subprocess.CompletedProcess[str]:
    cmd = [str(Path(repo_root, ".agents", "bin", "agents-monitor-loop.sh")), "--interval", "0", *extra_args]
    return subprocess.run(
        cmd,
        cwd=repo_root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=5,
    )


def test_runtime_guardrail() -> None:
    repo = _setup_repo("runtime")
    try:
        result = _run_monitor(repo)
    finally:
        shutil.rmtree(repo)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Runtime threshold exceeded" in result.stdout, result.stdout
    assert "^ 20251009-000000-monitor" in result.stdout, result.stdout


def test_heartbeat_guardrail() -> None:
    repo = _setup_repo("heartbeat")
    try:
        result = _run_monitor(repo)
    finally:
        shutil.rmtree(repo)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Log heartbeat threshold exceeded" in result.stdout, result.stdout
    assert "! 20251009-000001-monitor" in result.stdout, result.stdout


def test_no_subagents_exit() -> None:
    repo = _setup_repo("none")
    try:
        result = _run_monitor(repo)
    finally:
        shutil.rmtree(repo)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "No running subagents detected" in result.stdout, result.stdout


def test_multiple_subagents_table() -> None:
    repo = _setup_repo("multi")
    try:
        result = _run_monitor(repo, "--iterations", "1")
    finally:
        shutil.rmtree(repo)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "^" not in result.stdout, result.stdout
    assert "! " not in result.stdout, result.stdout
    assert "No running subagents detected" not in result.stdout, result.stdout
    assert "20251009-000010-monitor" in result.stdout, result.stdout
    assert "20251009-000011-monitor" in result.stdout, result.stdout


def test_stale_entry_exits() -> None:
    repo = _setup_repo("stale")
    try:
        result = _run_monitor(repo, "--iterations", "2")
    finally:
        shutil.rmtree(repo)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Stale subagent entry detected" in result.stdout, result.stdout


if __name__ == "__main__":
    test_runtime_guardrail()
    test_heartbeat_guardrail()
    test_no_subagents_exit()
