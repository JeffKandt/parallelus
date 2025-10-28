#!/usr/bin/env python3
"""Smoke tests for `.agents/bin/agents-monitor-loop.sh` guardrails.

The monitor loop script exits early when either the heartbeat threshold or
runtime threshold is exceeded, or when no subagents are running. These tests
simulate the `subagent_manager.sh status` output so we can assert the expected
markers (`!` and `^`) and exit messages without requiring a real registry.
"""

from __future__ import annotations

import json
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
    elif scenario == "nudge-failure":
        body = f"""
            #!/usr/bin/env bash
            set -euo pipefail
            cat <<'EOF'
{HEADER}
{SEPARATOR}
20251009-000030-monitor worktree   monitor-loop-nudge       running          pending      05:00     05:00     %2/@7          2025-10-09 19:15:00
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

    monitor_script = script_dest / "agents-monitor-loop.sh"
    shutil.copy2(SCRIPT_UNDER_TEST, monitor_script)
    mode = os.stat(monitor_script).st_mode
    os.chmod(monitor_script, mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    _write_stub(tmp_dir, scenario)

    tmux_safe = script_dest / "tmux-safe"
    tmux_safe.write_text(
        dedent(
            """
            #!/usr/bin/env bash
            set -euo pipefail
            exit 0
            """
        ).strip()
        + "\n",
        encoding="utf-8",
    )
    os.chmod(tmux_safe, os.stat(tmux_safe).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    send_keys_stub = script_dest / "subagent_send_keys.sh"
    exit_code = 1 if scenario == "nudge-failure" else 0
    send_keys_stub.write_text(
        dedent(
            f"""
            #!/usr/bin/env bash
            set -euo pipefail
            exit {exit_code}
            """
        ).strip()
        + "\n",
        encoding="utf-8",
    )
    os.chmod(send_keys_stub, os.stat(send_keys_stub).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    tail_stub = script_dest / "subagent_tail.sh"
    tail_stub.write_text(
        dedent(
            """
            #!/usr/bin/env bash
            set -euo pipefail
            exit 0
            """
        ).strip()
        + "\n",
        encoding="utf-8",
    )
    os.chmod(tail_stub, os.stat(tail_stub).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    registry_dir = tmp_dir / "docs" / "agents"
    registry_dir.mkdir(parents=True, exist_ok=True)
    registry_entries: list[dict[str, object]] = []
    if scenario == "nudge-failure":
        sandbox = tmp_dir / ".parallelus" / "subagents" / "sandboxes" / "monitor-loop-nudge"
        sandbox.mkdir(parents=True, exist_ok=True)
        (sandbox / "subagent.session.jsonl").write_text("[]\n", encoding="utf-8")
        registry_entries.append(
            {
                "id": "20251009-000030-monitor",
                "type": "throwaway",
                "slug": "monitor-loop-nudge",
                "status": "running",
                "path": str(sandbox),
                "launcher_kind": "tmux-pane",
                "launcher_handle": {"pane_id": "%2", "window_id": "@7"},
            }
        )
    (registry_dir / "subagent-registry.json").write_text(json.dumps(registry_entries, indent=2) + "\n", encoding="utf-8")

    subprocess.run(["git", "init", "-q"], cwd=tmp_dir, check=True)
    return tmp_dir


def _run_monitor(
    repo_root: Path, *extra_args: str, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    cmd = [str(Path(repo_root, ".agents", "bin", "agents-monitor-loop.sh")), "--interval", "0", *extra_args]
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(
        cmd,
        cwd=repo_root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=5,
        env=run_env,
    )


def test_runtime_guardrail() -> None:
    repo = _setup_repo("runtime")
    try:
        result = _run_monitor(repo)
    finally:
        shutil.rmtree(repo)

    assert result.returncode != 0, result.stdout + result.stderr
    assert "^ 20251009-000000-monitor" in result.stdout, result.stdout
    assert "requires manual attention" in result.stdout, result.stdout


def test_heartbeat_guardrail() -> None:
    repo = _setup_repo("heartbeat")
    try:
        result = _run_monitor(repo)
    finally:
        shutil.rmtree(repo)

    assert result.returncode != 0, result.stdout + result.stderr
    assert "! 20251009-000001-monitor" in result.stdout, result.stdout
    assert "requires manual attention" in result.stdout, result.stdout


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

    assert result.returncode != 0, result.stdout + result.stderr
    assert "requires manual attention" in result.stdout or "Stale subagent entry detected" in result.stdout, result.stdout


def test_nudge_helper_failure_reports_manual_attention() -> None:
    repo = _setup_repo("nudge-failure")
    try:
        env = {
            "MONITOR_NUDGE_MESSAGE": "poke",
            "MONITOR_RECHECK_DELAY": "0",
            "MONITOR_NUDGE_DELAY": "0",
            "MONITOR_SNAPSHOT_DIR": str(Path(repo, "snapshots")),
        }
        result = _run_monitor(repo, "--iterations", "1", env=env)
    finally:
        shutil.rmtree(repo)

    assert result.returncode != 0, result.stdout + result.stderr
    assert "nudge helper failed" in result.stdout, result.stdout
    assert "requires manual attention" in result.stdout, result.stdout


if __name__ == "__main__":
    test_runtime_guardrail()
    test_heartbeat_guardrail()
    test_no_subagents_exit()
