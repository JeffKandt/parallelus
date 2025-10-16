"""Basic smoke tests for project utilities."""

from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    """Run helper that enforces success and captures output."""
    return subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )


def test_subagent_launch_without_role_succeeds(tmp_path):
    """Launching a throwaway sandbox without an explicit role must not crash."""
    scope = ROOT / "docs/agents/templates/ci_audit_scope.md"
    slug = f"pytest-{tmp_path.name}"
    launch_cmd = [
        ".agents/bin/subagent_manager.sh",
        "launch",
        "--type",
        "throwaway",
        "--slug",
        slug,
        "--scope",
        str(scope),
        "--launcher",
        "manual",
    ]
    launch = run(launch_cmd)
    entry_id = launch.stdout.strip().splitlines()[-1]
    cleanup_cmd = [
        ".agents/bin/subagent_manager.sh",
        "cleanup",
        "--id",
        entry_id,
        "--force",
    ]
    try:
        assert entry_id, f"expected entry id in stdout, got: {launch.stdout!r}"
    finally:
        run(cleanup_cmd)
