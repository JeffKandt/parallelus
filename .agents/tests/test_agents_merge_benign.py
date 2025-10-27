"""Regression tests for agents-merge benign post-review tolerance."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

THIS_REPO = Path(__file__).resolve().parents[2]
MERGE_SCRIPT = THIS_REPO / ".agents" / "bin" / "agents-merge"
AGENTRC = THIS_REPO / ".agents" / "agentrc"


def _run(cmd: list[str], cwd: Path, env: dict | None = None, check: bool = True):
    result = subprocess.run(  # noqa: S603
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command {' '.join(cmd)} failed: {result.returncode}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return result


def _setup_repo() -> Path:
    tmpdir = Path(tempfile.mkdtemp(prefix="agents-merge-test-"))
    (tmpdir / ".agents" / "bin").mkdir(parents=True)
    shutil.copy2(MERGE_SCRIPT, tmpdir / ".agents" / "bin" / "agents-merge")
    os.chmod(tmpdir / ".agents" / "bin" / "agents-merge", 0o755)
    shutil.copy2(AGENTRC, tmpdir / ".agents" / "agentrc")
    _run(["git", "init", "-q"], cwd=tmpdir)
    _run(["git", "config", "user.name", "Test User"], cwd=tmpdir)
    _run(["git", "config", "user.email", "test@example.com"], cwd=tmpdir)

    # Baseline commit on main
    (tmpdir / "docs").mkdir()
    (tmpdir / "docs" / "PLAN.md").write_text("# Plan\n", encoding="utf-8")
    (tmpdir / "docs" / "PROGRESS.md").write_text("# Progress\n", encoding="utf-8")
    _run(["git", "add", "."], cwd=tmpdir)
    _run(["git", "commit", "-mq", "initial"], cwd=tmpdir)
    return tmpdir


def _prepare_benign_repo(tmpdir: Path) -> str:
    _run(["git", "checkout", "-qb", "feature/test"], cwd=tmpdir)
    code_file = tmpdir / "src.txt"
    code_file.write_text("base change\n", encoding="utf-8")
    _run(["git", "add", "src.txt"], cwd=tmpdir)
    _run(["git", "commit", "-mq", "feature work"], cwd=tmpdir)
    review_commit = _run(["git", "rev-parse", "HEAD"], cwd=tmpdir).stdout.strip()

    # Allowed doc-only follow-up (multiple commits)
    doc_dir = tmpdir / "docs" / "guardrails" / "runs" / "test"
    doc_dir.mkdir(parents=True, exist_ok=True)
    (doc_dir / "summary.md").write_text("benign\n", encoding="utf-8")
    review_file = tmpdir / "docs" / "reviews" / "feature-test-2025-10-27.md"
    review_file.parent.mkdir(parents=True, exist_ok=True)
    review_file.write_text(
        "\n".join(
            [
                "Reviewed-Branch: feature/test",
                f"Reviewed-Commit: {review_commit}",
                "Reviewed-On: 2025-10-27",
                "Decision: approved",
                "Reviewer: test",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    _run(["git", "add", "docs"], cwd=tmpdir)
    _run(["git", "commit", "-mq", "doc follow-up"], cwd=tmpdir)
    (tmpdir / "docs" / "PROGRESS.md").write_text("# Progress\nupdated\n", encoding="utf-8")
    _run(["git", "add", "docs/PROGRESS.md"], cwd=tmpdir)
    _run(["git", "commit", "-mq", "progress update"], cwd=tmpdir)
    return "test"


def _prepare_non_benign_repo(tmpdir: Path) -> str:
    _run(["git", "checkout", "-qb", "feature/fail"], cwd=tmpdir)
    code_file = tmpdir / "src.txt"
    code_file.write_text("base change\n", encoding="utf-8")
    _run(["git", "add", "src.txt"], cwd=tmpdir)
    _run(["git", "commit", "-mq", "feature work"], cwd=tmpdir)
    review_commit = _run(["git", "rev-parse", "HEAD"], cwd=tmpdir).stdout.strip()

    # Follow-up touches code (not allowed)
    (tmpdir / "extra.py").write_text("print('hi')\n", encoding="utf-8")
    review_file = tmpdir / "docs" / "reviews" / "feature-fail-2025-10-27.md"
    review_file.parent.mkdir(parents=True, exist_ok=True)
    review_file.write_text(
        "\n".join(
            [
                "Reviewed-Branch: feature/fail",
                f"Reviewed-Commit: {review_commit}",
                "Reviewed-On: 2025-10-27",
                "Decision: approved",
                "Reviewer: test",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    _run(["git", "add", "."], cwd=tmpdir)
    _run(["git", "commit", "-mq", "code follow-up"], cwd=tmpdir)
    return "fail"


def test_agents_merge_allows_benign_doc_commit():
    tmpdir = _setup_repo()
    try:
        slug = _prepare_benign_repo(tmpdir)
        env = os.environ.copy()
        env.setdefault("AGENTS_ALLOW_MAIN_COMMIT", "1")
        result = _run([".agents/bin/agents-merge", slug], cwd=tmpdir, env=env, check=False)
        assert result.returncode == 0, f"Expected success, got {result.returncode}: {result.stderr}"
    finally:
        shutil.rmtree(tmpdir)


def test_agents_merge_rejects_non_benign_commit():
    tmpdir = _setup_repo()
    try:
        slug = _prepare_non_benign_repo(tmpdir)
        env = os.environ.copy()
        env.setdefault("AGENTS_ALLOW_MAIN_COMMIT", "1")
        result = _run([".agents/bin/agents-merge", slug], cwd=tmpdir, env=env, check=False)
        assert result.returncode != 0, "Expected failure for code diff after review"
    finally:
        shutil.rmtree(tmpdir)
