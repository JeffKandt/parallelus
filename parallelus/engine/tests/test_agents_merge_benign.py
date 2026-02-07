"""Regression tests for agents-merge benign post-review tolerance."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

THIS_REPO = Path(__file__).resolve().parents[3]
MERGE_SCRIPT = THIS_REPO / "parallelus/engine" / "bin" / "agents-merge"
DOC_PATHS_SCRIPT = THIS_REPO / "parallelus/engine" / "bin" / "agents-doc-paths.sh"
AGENTRC = THIS_REPO / "parallelus/engine" / "agentrc"


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
    (tmpdir / "parallelus/engine" / "bin").mkdir(parents=True)
    shutil.copy2(MERGE_SCRIPT, tmpdir / "parallelus/engine" / "bin" / "agents-merge")
    os.chmod(tmpdir / "parallelus/engine" / "bin" / "agents-merge", 0o755)
    shutil.copy2(DOC_PATHS_SCRIPT, tmpdir / "parallelus/engine" / "bin" / "agents-doc-paths.sh")
    os.chmod(tmpdir / "parallelus/engine" / "bin" / "agents-doc-paths.sh", 0o755)
    detect_stub = tmpdir / "parallelus/engine" / "bin" / "agents-detect"
    detect_stub.write_text(
        "echo 'REPO_MODE=remote-connected'\n"
        "echo 'BASE_BRANCH=main'\n"
        "echo 'HAS_REMOTE=false'\n",
        encoding="utf-8",
    )
    os.chmod(detect_stub, 0o755)
    shutil.copy2(AGENTRC, tmpdir / "parallelus/engine" / "agentrc")
    _run(["git", "init", "-q"], cwd=tmpdir)
    _run(["git", "config", "user.name", "Test User"], cwd=tmpdir)
    _run(["git", "config", "user.email", "test@example.com"], cwd=tmpdir)

    # Baseline commit on main
    (tmpdir / "docs").mkdir()
    (tmpdir / "docs" / "PLAN.md").write_text("# Plan\n", encoding="utf-8")
    (tmpdir / "docs" / "PROGRESS.md").write_text("# Progress\n", encoding="utf-8")
    (tmpdir / "Makefile").write_text("ci:\n\t@echo \"ci stub\"\n", encoding="utf-8")
    _run(["git", "add", "."], cwd=tmpdir)
    _run(["git", "commit", "-qm", "initial"], cwd=tmpdir)
    return tmpdir


def _prepare_benign_repo(tmpdir: Path) -> str:
    _run(["git", "checkout", "-qb", "feature/test"], cwd=tmpdir)
    code_file = tmpdir / "src.txt"
    code_file.write_text("base change\n", encoding="utf-8")
    _run(["git", "add", "src.txt"], cwd=tmpdir)
    _run(["git", "commit", "-qm", "feature work"], cwd=tmpdir)

    marker_timestamp = "2025-11-02T00:00:00Z"
    markers_dir = tmpdir / "docs" / "parallelus" / "self-improvement" / "markers"
    reports_dir = tmpdir / "docs" / "parallelus" / "self-improvement" / "reports"
    failures_dir = tmpdir / "docs" / "parallelus" / "self-improvement" / "failures"
    markers_dir.mkdir(parents=True, exist_ok=True)
    reports_dir.mkdir(parents=True, exist_ok=True)
    failures_dir.mkdir(parents=True, exist_ok=True)
    slugged = "feature-test"
    (markers_dir / f"{slugged}.json").write_text(
        json.dumps({"timestamp": marker_timestamp}, indent=2) + "\n",
        encoding="utf-8",
    )
    (reports_dir / f"{slugged}--{marker_timestamp}.json").write_text(
        json.dumps({"branch": "feature/test", "marker_timestamp": marker_timestamp}, indent=2) + "\n",
        encoding="utf-8",
    )
    (failures_dir / f"{slugged}--{marker_timestamp}.json").write_text(
        json.dumps({"branch": "feature/test", "marker_timestamp": marker_timestamp, "failures": []}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    _run(["git", "add", "docs/parallelus/self-improvement"], cwd=tmpdir)
    _run(["git", "commit", "-qm", "add audit artifacts"], cwd=tmpdir)
    review_commit = _run(["git", "rev-parse", "HEAD"], cwd=tmpdir).stdout.strip()

    # Allowed doc-only follow-up (multiple commits)
    doc_dir = tmpdir / "docs" / "guardrails" / "runs" / "test"
    doc_dir.mkdir(parents=True, exist_ok=True)
    (doc_dir / "summary.md").write_text("benign\n", encoding="utf-8")
    review_file = tmpdir / "docs" / "parallelus" / "reviews" / "feature-test-2025-10-27.md"
    review_file.parent.mkdir(parents=True, exist_ok=True)
    review_file.write_text(
        "\n".join(
            [
                "Reviewed-Branch: feature/test",
                f"Reviewed-Commit: {review_commit}",
                "Reviewed-On: 2025-10-27",
                "Decision: approved",
                "Reviewer: test",
                "Session Mode: synchronous subagent",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    _run(["git", "add", "docs/parallelus/reviews", "docs/guardrails"], cwd=tmpdir)
    _run(["git", "commit", "-qm", "doc follow-up"], cwd=tmpdir)

    (tmpdir / "docs" / "PROGRESS.md").write_text("# Progress\nupdated\n", encoding="utf-8")
    _run(["git", "add", "docs/PROGRESS.md"], cwd=tmpdir)
    _run(["git", "commit", "-qm", "progress update"], cwd=tmpdir)
    return "test"


def _prepare_non_benign_repo(tmpdir: Path) -> str:
    _run(["git", "checkout", "-qb", "feature/fail"], cwd=tmpdir)
    code_file = tmpdir / "src.txt"
    code_file.write_text("base change\n", encoding="utf-8")
    _run(["git", "add", "src.txt"], cwd=tmpdir)
    _run(["git", "commit", "-qm", "feature work"], cwd=tmpdir)

    marker_timestamp = "2025-11-02T00:00:00Z"
    markers_dir = tmpdir / "docs" / "parallelus" / "self-improvement" / "markers"
    reports_dir = tmpdir / "docs" / "parallelus" / "self-improvement" / "reports"
    failures_dir = tmpdir / "docs" / "parallelus" / "self-improvement" / "failures"
    markers_dir.mkdir(parents=True, exist_ok=True)
    reports_dir.mkdir(parents=True, exist_ok=True)
    failures_dir.mkdir(parents=True, exist_ok=True)
    slugged = "feature-fail"
    (markers_dir / f"{slugged}.json").write_text(
        json.dumps({"timestamp": marker_timestamp}, indent=2) + "\n",
        encoding="utf-8",
    )
    (reports_dir / f"{slugged}--{marker_timestamp}.json").write_text(
        json.dumps({"branch": "feature/fail", "marker_timestamp": marker_timestamp}, indent=2) + "\n",
        encoding="utf-8",
    )
    (failures_dir / f"{slugged}--{marker_timestamp}.json").write_text(
        json.dumps({"branch": "feature/fail", "marker_timestamp": marker_timestamp, "failures": []}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    _run(["git", "add", "docs/parallelus/self-improvement"], cwd=tmpdir)
    _run(["git", "commit", "-qm", "add audit artifacts"], cwd=tmpdir)
    review_commit = _run(["git", "rev-parse", "HEAD"], cwd=tmpdir).stdout.strip()

    # Follow-up touches code (not allowed)
    (tmpdir / "extra.py").write_text("print('hi')\n", encoding="utf-8")
    review_file = tmpdir / "docs" / "parallelus" / "reviews" / "feature-fail-2025-10-27.md"
    review_file.parent.mkdir(parents=True, exist_ok=True)
    review_file.write_text(
        "\n".join(
            [
                "Reviewed-Branch: feature/fail",
                f"Reviewed-Commit: {review_commit}",
                "Reviewed-On: 2025-10-27",
                "Decision: approved",
                "Reviewer: test",
                "Session Mode: synchronous subagent",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    _run(["git", "add", "."], cwd=tmpdir)
    _run(["git", "commit", "-qm", "code follow-up"], cwd=tmpdir)
    return "fail"


def test_agents_merge_allows_benign_doc_commit():
    tmpdir = _setup_repo()
    try:
        slug = _prepare_benign_repo(tmpdir)
        env = os.environ.copy()
        env.setdefault("AGENTS_ALLOW_MAIN_COMMIT", "1")
        result = _run(["parallelus/engine/bin/agents-merge", slug], cwd=tmpdir, env=env, check=False)
        assert result.returncode == 0, f"Expected success, got {result.returncode}: {result.stderr}"
    finally:
        shutil.rmtree(tmpdir)


def test_agents_merge_rejects_non_benign_commit():
    tmpdir = _setup_repo()
    try:
        slug = _prepare_non_benign_repo(tmpdir)
        env = os.environ.copy()
        env.setdefault("AGENTS_ALLOW_MAIN_COMMIT", "1")
        result = _run(["parallelus/engine/bin/agents-merge", slug], cwd=tmpdir, env=env, check=False)
        assert result.returncode != 0, "Expected failure for code diff after review"
    finally:
        shutil.rmtree(tmpdir)


def test_agents_merge_skip_retro_logs_outside_repo():
    tmpdir = _setup_repo()
    state_root = Path(tmpdir).parent / ".parallelus"
    shutil.rmtree(state_root, ignore_errors=True)
    try:
        slug = _prepare_benign_repo(tmpdir)
        env = os.environ.copy()
        env.setdefault("AGENTS_ALLOW_MAIN_COMMIT", "1")
        env.setdefault("AGENTS_MERGE_SKIP_RETRO", "1")
        env.setdefault("AGENTS_MERGE_SKIP_RETRO_REASON", "skip for test")
        stub_dir = Path(tempfile.mkdtemp(prefix="agents-merge-make-stub-"))
        make_stub = stub_dir / "make"
        make_stub.write_text(
            "#!/usr/bin/env bash\nexit 1\n",
            encoding="utf-8",
        )
        os.chmod(make_stub, 0o755)
        env.setdefault("AGENTS_MERGE_SKIP_CI", "1")
        env["PATH"] = f"{stub_dir}:{env.get('PATH', '')}"
        result = _run(["parallelus/engine/bin/agents-merge", slug], cwd=tmpdir, env=env, check=False)
        assert result.returncode == 0, f"Expected success, got {result.returncode}: {result.stderr}"
        skip_dir = state_root / "retro-skip-logs"
        pattern = f"feature-{slug}--*.json"
        matches = list(skip_dir.glob(pattern))
        assert matches, f"Expected skip log matching {pattern}"
        for path in matches:
            assert not str(path).startswith(str(tmpdir)), "Skip log should not reside inside repo root"
            data = json.loads(path.read_text(encoding="utf-8"))
            assert data["reason"] == "skip for test"
    finally:
        shutil.rmtree(tmpdir)
        shutil.rmtree(stub_dir, ignore_errors=True)
        shutil.rmtree(state_root, ignore_errors=True)
