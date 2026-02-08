"""Basic smoke tests for project utilities."""

import os
import subprocess
from pathlib import Path
from typing import Dict, Optional


ROOT = Path(__file__).resolve().parents[1]


def run(
    cmd: list[str], *, env_overrides: Optional[Dict[str, str]] = None
) -> subprocess.CompletedProcess[str]:
    """Run helper that enforces success and captures output."""
    env = os.environ.copy()
    env.setdefault("SUBAGENT_MANAGER_ALLOW_MAIN", "1")
    if env_overrides:
        env.update(env_overrides)
    return subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
        env=env,
    )


def test_subagent_launch_without_role_succeeds(tmp_path):
    """Launching a throwaway sandbox without an explicit role must not crash."""
    scope = ROOT / "parallelus/manuals/templates/ci_audit_scope.md"
    slug = f"pytest-{tmp_path.name}"
    registry_file = tmp_path / "subagent-registry.json"
    env_overrides = {
        "SUBAGENT_REGISTRY_FILE": str(registry_file),
    }
    launch_cmd = [
        "parallelus/engine/bin/subagent_manager.sh",
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
    launch = run(launch_cmd, env_overrides=env_overrides)
    entry_id = launch.stdout.strip().splitlines()[-1]
    cleanup_cmd = [
        "parallelus/engine/bin/subagent_manager.sh",
        "cleanup",
        "--id",
        entry_id,
        "--force",
    ]
    try:
        assert entry_id, f"expected entry id in stdout, got: {launch.stdout!r}"
    finally:
        run(cleanup_cmd, env_overrides=env_overrides)
