"""Managed hook drift detection + auto-sync regression tests."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]


def _run(cmd: list[str], cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(cmd, cwd=cwd, env=run_env, text=True, capture_output=True, check=False)


def _init_repo(tmp: Path) -> None:
    shutil.copytree(REPO_ROOT / "parallelus/engine", tmp / "parallelus/engine")
    _run(["git", "init", "-q"], cwd=tmp)
    _run(["git", "config", "user.name", "Hook Sync Tests"], cwd=tmp)
    _run(["git", "config", "user.email", "hook.sync@example.com"], cwd=tmp)
    (tmp / "README.md").write_text("hook-sync-tests\n", encoding="utf-8")
    _run(["git", "add", "."], cwd=tmp)
    _run(["git", "commit", "-q", "-m", "init"], cwd=tmp)
    _run(["git", "checkout", "-q", "-b", "feature/hook-sync"], cwd=tmp)


def test_agents_detect_auto_syncs_drifted_hooks() -> None:
    with tempfile.TemporaryDirectory(prefix="hook-sync-auto-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo)

        install = _run([str(repo / "parallelus/engine" / "bin" / "install-hooks"), "--quiet"], cwd=repo)
        assert install.returncode == 0, install.stderr

        managed = repo / "parallelus" / "engine" / "hooks" / "pre-commit"
        installed = repo / ".git" / "hooks" / "pre-commit"
        installed.write_text("#!/usr/bin/env bash\necho drift\n", encoding="utf-8")
        installed.chmod(0o755)

        detect = _run([str(repo / "parallelus/engine" / "bin" / "agents-detect")], cwd=repo)
        assert detect.returncode == 0, detect.stderr
        assert "ensure-hooks-synced: managed hook drift detected; auto-syncing hooks." in detect.stderr
        assert installed.read_text(encoding="utf-8") == managed.read_text(encoding="utf-8")


def test_agents_detect_reports_hook_drift_when_auto_sync_disabled() -> None:
    with tempfile.TemporaryDirectory(prefix="hook-sync-disabled-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo)

        install = _run([str(repo / "parallelus/engine" / "bin" / "install-hooks"), "--quiet"], cwd=repo)
        assert install.returncode == 0, install.stderr

        managed = repo / "parallelus" / "engine" / "hooks" / "pre-commit"
        installed = repo / ".git" / "hooks" / "pre-commit"
        installed.write_text("#!/usr/bin/env bash\necho drift-disabled\n", encoding="utf-8")
        installed.chmod(0o755)

        detect = _run(
            [str(repo / "parallelus/engine" / "bin" / "agents-detect")],
            cwd=repo,
            env={"AGENTS_HOOK_AUTO_SYNC": "0"},
        )
        assert detect.returncode == 0, detect.stderr
        assert "ensure-hooks-synced: managed hook drift detected; auto-sync disabled (AGENTS_HOOK_AUTO_SYNC=0)." in detect.stderr
        assert installed.read_text(encoding="utf-8") != managed.read_text(encoding="utf-8")
