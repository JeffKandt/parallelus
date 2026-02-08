"""Regression tests for serialized senior-review preflight helpers."""

from __future__ import annotations

import json
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


def _init_repo(tmp: Path, branch: str = "feature/preflight") -> None:
    shutil.copytree(REPO_ROOT / "parallelus/engine", tmp / "parallelus/engine")
    shutil.copytree(REPO_ROOT / "parallelus/manuals/templates", tmp / "parallelus/manuals/templates")
    for cache_dir in (tmp / "parallelus/engine").rglob("__pycache__"):
        shutil.rmtree(cache_dir, ignore_errors=True)

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

        retro = _run([str(repo / "parallelus/engine" / "bin" / "retro-marker")], cwd=repo)
        assert retro.returncode == 0, retro.stderr

        collect = _run([str(repo / "parallelus/engine" / "bin" / "collect_failures.py")], cwd=repo)
        assert collect.returncode == 0, collect.stderr

        audit = _run([str(repo / "parallelus/engine" / "bin" / "retro_audit_local.py")], cwd=repo)
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
            [str(repo / "parallelus/engine" / "bin" / "subagent_manager.sh"), "review-preflight", "--no-launch"],
            cwd=repo,
            env={"AGENTS_REQUIRE_RETRO": "1"},
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

        verify = _run([str(repo / "parallelus/engine" / "bin" / "verify-retrospective")], cwd=repo)
        assert verify.returncode == 0, verify.stderr


def test_review_preflight_default_launch_marks_awaiting_when_not_started() -> None:
    with tempfile.TemporaryDirectory(prefix="review-preflight-launch-status-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/preflight-launch-status"
        _init_repo(repo, branch=branch)
        for name in ("markers", "reports", "failures"):
            leaf = repo / "docs" / "parallelus" / "self-improvement" / name
            leaf.mkdir(parents=True, exist_ok=True)
            (leaf / ".gitkeep").write_text("", encoding="utf-8")
        manuals_dir = repo / "parallelus" / "manuals"
        manuals_dir.mkdir(parents=True, exist_ok=True)
        (manuals_dir / "subagent-registry.json").write_text("[]\n", encoding="utf-8")
        _run(["git", "add", "docs/parallelus/self-improvement"], cwd=repo)
        _run(["git", "add", "parallelus/manuals/subagent-registry.json"], cwd=repo)
        _run(["git", "commit", "-q", "-m", "seed self-improvement scaffold"], cwd=repo)
        (repo / ".gitignore").write_text(".parallelus/\nparallelus/engine/bin/__pycache__/\n", encoding="utf-8")
        _run(["git", "add", ".gitignore"], cwd=repo)
        _run(["git", "commit", "-q", "-m", "ignore runtime workspace"], cwd=repo)

        # Stub launcher emits no handle/json, simulating "print manual instructions only".
        launcher_stub_dir = Path(tempfile.mkdtemp(prefix="review-preflight-launcher-stub-"))
        launcher_stub = launcher_stub_dir / "launcher-stub.sh"
        launcher_stub.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        launcher_stub.chmod(0o755)

        cmd = _run(
            [str(repo / "parallelus/engine" / "bin" / "subagent_manager.sh"), "review-preflight"],
            cwd=repo,
            env={"SUBAGENT_LAUNCH_HELPER": str(launcher_stub), "AGENTS_REQUIRE_RETRO": "1"},
        )
        assert cmd.returncode == 0, cmd.stderr
        assert "awaiting_manual_launch" in cmd.stderr

        registry_path = repo / "parallelus" / "manuals" / "subagent-registry.json"
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data, "expected a launch registry entry"
        entry = data[-1]
        assert entry["launcher"] == "auto"
        assert entry["status"] == "awaiting_manual_launch"


def test_review_preflight_run_executes_manual_fallback_and_cleans_up() -> None:
    with tempfile.TemporaryDirectory(prefix="review-preflight-run-wrapper-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/preflight-wrapper"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)
        for name in ("markers", "reports", "failures"):
            leaf = repo / "docs" / "parallelus" / "self-improvement" / name
            leaf.mkdir(parents=True, exist_ok=True)
            (leaf / ".gitkeep").write_text("", encoding="utf-8")
        manuals_dir = repo / "parallelus" / "manuals"
        manuals_dir.mkdir(parents=True, exist_ok=True)
        (manuals_dir / "subagent-registry.json").write_text("[]\n", encoding="utf-8")
        _run(["git", "add", "docs/parallelus/self-improvement"], cwd=repo)
        _run(["git", "add", "parallelus/manuals/subagent-registry.json"], cwd=repo)
        _run(["git", "commit", "-q", "-m", "seed self-improvement scaffold"], cwd=repo)
        (repo / ".gitignore").write_text(".parallelus/\nparallelus/engine/bin/__pycache__/\n", encoding="utf-8")
        _run(["git", "add", ".gitignore"], cwd=repo)
        _run(["git", "commit", "-q", "-m", "ignore runtime workspace"], cwd=repo)

        launcher_stub_dir = Path(tempfile.mkdtemp(prefix="review-preflight-launcher-stub-"))

        codex_stub = launcher_stub_dir / "codex"
        codex_stub.write_text(
            f"""#!/usr/bin/env bash
set -euo pipefail
commit=$(git rev-parse HEAD)
mkdir -p docs/parallelus/reviews
cat > "docs/parallelus/reviews/{slug}-2099-01-01.md" <<EOF
Reviewed-Branch: {branch}
Reviewed-Commit: ${{commit}}
Reviewed-On: 2099-01-01
Decision: approved
EOF
exit 0
""",
            encoding="utf-8",
        )
        codex_stub.chmod(0o755)

        cmd = _run(
            [str(repo / "parallelus/engine" / "bin" / "subagent_manager.sh"), "review-preflight-run"],
            cwd=repo,
            env={
                # Keep tmux off PATH so launch falls back to manual instructions.
                "PATH": f"{launcher_stub_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
                "AGENTS_REQUIRE_RETRO": "1",
            },
        )
        assert cmd.returncode == 0, cmd.stderr
        assert "review-preflight-run: running manual launcher" in cmd.stderr
        assert "Harvested deliverables:" in cmd.stderr
        assert "Cleaned " in cmd.stdout

        review_file = repo / "docs" / "parallelus" / "reviews" / f"{slug}-2099-01-01.md"
        assert review_file.exists()

        registry_path = repo / "parallelus" / "manuals" / "subagent-registry.json"
        data = json.loads(registry_path.read_text(encoding="utf-8"))
        assert data, "expected a launch registry entry"
        entry = data[-1]
        assert entry["status"] == "cleaned"
        assert entry.get("deliverables_status") == "harvested"
        assert not Path(entry["path"]).exists()


def test_review_preflight_no_launch_skips_retro_pipeline_when_disabled() -> None:
    with tempfile.TemporaryDirectory(prefix="review-preflight-skip-retro-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/preflight-skip-retro"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        cmd = _run(
            [str(repo / "parallelus/engine" / "bin" / "subagent_manager.sh"), "review-preflight", "--no-launch"],
            cwd=repo,
            env={"AGENTS_REQUIRE_RETRO": "0"},
        )
        assert cmd.returncode == 0, cmd.stderr
        assert "AGENTS_REQUIRE_RETRO=0; skipping retrospective preflight pipeline." in cmd.stderr
        assert "review-preflight: complete (launch skipped)" in cmd.stderr

        marker_path = repo / "docs" / "parallelus" / "self-improvement" / "markers" / f"{slug}.json"
        assert not marker_path.exists()
