"""Regression tests for serialized senior-review preflight helpers."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run(cmd: list[str], cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(cmd, cwd=cwd, env=run_env, text=True, capture_output=True, check=False)


def _init_repo(tmp: Path, branch: str = "feature/preflight") -> None:
    shutil.copytree(REPO_ROOT / ".agents", tmp / ".agents")

    slug = branch.replace("/", "-")
    notebook_dir = tmp / "docs" / "branches" / slug
    notebook_dir.mkdir(parents=True, exist_ok=True)
    (notebook_dir / "PLAN.md").write_text(f"# Branch Plan — {branch}\n", encoding="utf-8")
    (notebook_dir / "PROGRESS.md").write_text(f"# Branch Progress — {branch}\n", encoding="utf-8")

    _run(["git", "init", "-q"], cwd=tmp)
    _run(["git", "config", "user.name", "Review Preflight Tests"], cwd=tmp)
    _run(["git", "config", "user.email", "review.preflight@example.com"], cwd=tmp)
    (tmp / "README.md").write_text("review-preflight-tests\n", encoding="utf-8")
    _run(["git", "add", "."], cwd=tmp)
    _run(["git", "commit", "-q", "-m", "init"], cwd=tmp)
    _run(["git", "checkout", "-q", "-b", branch], cwd=tmp)


def test_retro_audit_local_writes_marker_matched_report() -> None:
    with tempfile.TemporaryDirectory(prefix="review-preflight-local-audit-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/local-audit"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        retro = _run([str(repo / ".agents" / "bin" / "retro-marker")], cwd=repo)
        assert retro.returncode == 0, retro.stderr

        collect = _run([str(repo / ".agents" / "bin" / "collect_failures.py")], cwd=repo)
        assert collect.returncode == 0, collect.stderr

        audit = _run([str(repo / ".agents" / "bin" / "retro_audit_local.py")], cwd=repo)
        assert audit.returncode == 0, audit.stderr
        assert "retro_audit_local: wrote" in audit.stdout

        marker_path = repo / "docs" / "parallelus" / "self-improvement" / "markers" / f"{slug}.json"
        marker = json.loads(marker_path.read_text(encoding="utf-8"))
        ts = marker["timestamp"]
        report_path = (
            repo
            / "docs"
            / "parallelus"
            / "self-improvement"
            / "reports"
            / f"{slug}--{ts}.json"
        )
        assert report_path.exists()
        report = json.loads(report_path.read_text(encoding="utf-8"))
        assert report["branch"] == branch
        assert report["marker_timestamp"] == ts
        assert report["mode"] == "local_commit_aware"


def test_review_preflight_no_launch_creates_marker_linked_artifacts() -> None:
    with tempfile.TemporaryDirectory(prefix="review-preflight-cmd-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/preflight-cmd"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        cmd = _run(
            [str(repo / ".agents" / "bin" / "subagent_manager.sh"), "review-preflight", "--no-launch"],
            cwd=repo,
        )
        assert cmd.returncode == 0, cmd.stderr
        assert "review-preflight: complete (launch skipped)" in cmd.stderr

        marker_path = repo / "docs" / "parallelus" / "self-improvement" / "markers" / f"{slug}.json"
        marker = json.loads(marker_path.read_text(encoding="utf-8"))
        ts = marker["timestamp"]

        failures_path = (
            repo
            / "docs"
            / "parallelus"
            / "self-improvement"
            / "failures"
            / f"{slug}--{ts}.json"
        )
        report_path = (
            repo
            / "docs"
            / "parallelus"
            / "self-improvement"
            / "reports"
            / f"{slug}--{ts}.json"
        )
        assert failures_path.exists()
        assert report_path.exists()

        verify = _run([str(repo / ".agents" / "bin" / "verify-retrospective")], cwd=repo)
        assert verify.returncode == 0, verify.stderr
