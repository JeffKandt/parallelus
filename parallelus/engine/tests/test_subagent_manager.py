"""Regression tests for subagent_manager deliverable handling."""

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


def _init_repo(tmp: Path, branch: str = "feature/demo") -> None:
    shutil.copytree(REPO_ROOT / "parallelus/engine", tmp / "parallelus/engine")
    (tmp / "parallelus" / "manuals").mkdir(parents=True, exist_ok=True)
    (tmp / "docs" / "parallelus" / "reviews").mkdir(parents=True, exist_ok=True)

    _run(["git", "init", "-q"], cwd=tmp)
    _run(["git", "config", "user.name", "Subagent Tests"], cwd=tmp)
    _run(["git", "config", "user.email", "subagent.tests@example.com"], cwd=tmp)
    (tmp / "README.md").write_text("subagent-manager-tests\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=tmp)
    _run(["git", "commit", "-q", "-m", "init"], cwd=tmp)
    _run(["git", "checkout", "-q", "-b", branch], cwd=tmp)


def _registry_path(repo: Path) -> Path:
    return repo / "parallelus" / "manuals" / "subagent-registry.json"


def _manager_path(repo: Path) -> Path:
    return repo / "parallelus/engine" / "bin" / "subagent_manager.sh"


def test_harvest_detects_changed_baseline_review_file() -> None:
    with tempfile.TemporaryDirectory(prefix="subagent-harvest-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/demo"
        branch_slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)
        head = (
            _run(["git", "rev-parse", "HEAD"], cwd=repo)
            .stdout.strip()
        )
        assert head

        sandbox = repo / ".parallelus" / "subagents" / "sandboxes" / "senior-review-test"
        review_rel = f"docs/parallelus/reviews/{branch_slug}-2026-02-07.md"
        review_file = sandbox / review_rel
        review_file.parent.mkdir(parents=True, exist_ok=True)
        review_file.write_text(
            "\n".join(
                [
                    f"Reviewed-Branch: {branch}",
                    f"Reviewed-Commit: {head}",
                    "Reviewed-On: 2026-02-07T16:00:00Z",
                    "Decision: approved",
                    "",
                    "Phase gate evidence.",
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        registry = _registry_path(repo)
        registry.write_text(
            json.dumps(
                [
                    {
                        "id": "test-harvest",
                        "type": "throwaway",
                        "slug": "senior-review",
                        "path": str(sandbox),
                        "status": "verified",
                        "source_branch": branch,
                        "source_commit": head,
                        "deliverables_status": "waiting",
                        "deliverables": [
                            {
                                "id": "senior-review-report",
                                "kind": "review_markdown",
                                "source_glob": f"docs/parallelus/reviews/{branch_slug}-*.md",
                                "baseline": [review_rel],
                                "baseline_fingerprints": {review_rel: "file:old-fingerprint"},
                                "status": "waiting",
                            }
                        ],
                    }
                ],
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        result = _run(
            [str(_manager_path(repo)), "harvest", "--id", "test-harvest"],
            cwd=repo,
            env={"SUBAGENT_REGISTRY_FILE": str(registry)},
        )
        assert result.returncode == 0, result.stderr
        assert "Harvested deliverables" in result.stderr

        copied_review = repo / review_rel
        assert copied_review.exists()
        assert f"Reviewed-Commit: {head}" in copied_review.read_text(encoding="utf-8")

        data = json.loads(registry.read_text(encoding="utf-8"))
        row = data[0]
        deliverable = row["deliverables"][0]
        assert row["deliverables_status"] == "harvested"
        assert deliverable["status"] == "harvested"
        assert review_rel in deliverable.get("baseline", [])
        assert deliverable.get("baseline_fingerprints", {}).get(review_rel) != "file:old-fingerprint"


def test_cleanup_blocks_unharvested_deliverables_without_force() -> None:
    with tempfile.TemporaryDirectory(prefix="subagent-cleanup-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo, branch="feature/cleanup")

        sandbox = repo / ".parallelus" / "subagents" / "sandboxes" / "cleanup-test"
        sandbox.mkdir(parents=True, exist_ok=True)
        (sandbox / "subagent.log").write_text("done\n", encoding="utf-8")

        registry = _registry_path(repo)
        registry.write_text(
            json.dumps(
                [
                    {
                        "id": "test-cleanup",
                        "type": "throwaway",
                        "slug": "senior-review",
                        "path": str(sandbox),
                        "status": "verified",
                        "deliverables_status": "waiting",
                        "deliverables": [
                            {
                                "id": "senior-review-report",
                                "source_glob": "docs/parallelus/reviews/feature-cleanup-*.md",
                                "status": "waiting",
                            }
                        ],
                    }
                ],
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        blocked = _run(
            [str(_manager_path(repo)), "cleanup", "--id", "test-cleanup"],
            cwd=repo,
            env={"SUBAGENT_REGISTRY_FILE": str(registry)},
        )
        assert blocked.returncode != 0
        assert "deliverables remain unharvested" in blocked.stderr
        assert sandbox.exists()

        forced = _run(
            [str(_manager_path(repo)), "cleanup", "--id", "test-cleanup", "--force"],
            cwd=repo,
            env={"SUBAGENT_REGISTRY_FILE": str(registry)},
        )
        assert forced.returncode == 0, forced.stderr
        assert not sandbox.exists()

        data = json.loads(registry.read_text(encoding="utf-8"))
        assert data[0]["status"] == "cleaned"


def test_abort_marks_entry_and_preserves_sandbox() -> None:
    with tempfile.TemporaryDirectory(prefix="subagent-abort-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo, branch="feature/abort")

        sandbox = repo / ".parallelus" / "subagents" / "sandboxes" / "abort-test"
        sandbox.mkdir(parents=True, exist_ok=True)
        (sandbox / "subagent.log").write_text("running\n", encoding="utf-8")

        registry = _registry_path(repo)
        registry.write_text(
            json.dumps(
                [
                    {
                        "id": "test-abort",
                        "type": "throwaway",
                        "slug": "ci-audit",
                        "path": str(sandbox),
                        "status": "running",
                        "launcher_kind": "",
                        "launcher_handle": {},
                    }
                ],
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        aborted = _run(
            [str(_manager_path(repo)), "abort", "--id", "test-abort", "--reason", "timeout"],
            cwd=repo,
            env={"SUBAGENT_REGISTRY_FILE": str(registry)},
        )
        assert aborted.returncode == 0, aborted.stderr
        assert "Aborted test-abort" in aborted.stdout
        assert sandbox.exists()

        data = json.loads(registry.read_text(encoding="utf-8"))
        row = data[0]
        assert row["status"] == "aborted_timeout"
        assert row.get("aborted_reason") == "timeout"
        assert row.get("aborted_at")

        cleaned = _run(
            [str(_manager_path(repo)), "cleanup", "--id", "test-abort", "--force"],
            cwd=repo,
            env={"SUBAGENT_REGISTRY_FILE": str(registry)},
        )
        assert cleaned.returncode == 0, cleaned.stderr
        assert not sandbox.exists()


def test_senior_review_launch_fails_when_marker_head_mismatches() -> None:
    with tempfile.TemporaryDirectory(prefix="subagent-marker-head-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/review-head"
        _init_repo(repo, branch=branch)

        head = _run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
        assert head
        stale_head = "0" * 40 if head != "0" * 40 else "1" * 40

        slug = branch.replace("/", "-")
        marker_ts = "2026-02-07T17:40:00Z"
        marker_dir = repo / "docs" / "parallelus" / "self-improvement" / "markers"
        reports_dir = repo / "docs" / "parallelus" / "self-improvement" / "reports"
        failures_dir = repo / "docs" / "parallelus" / "self-improvement" / "failures"
        marker_dir.mkdir(parents=True, exist_ok=True)
        reports_dir.mkdir(parents=True, exist_ok=True)
        failures_dir.mkdir(parents=True, exist_ok=True)
        (marker_dir / f"{slug}.json").write_text(
            json.dumps({"timestamp": marker_ts, "head": stale_head}, indent=2) + "\n",
            encoding="utf-8",
        )
        (reports_dir / f"{slug}--{marker_ts}.json").write_text(
            json.dumps({"branch": branch, "marker_timestamp": marker_ts, "issues": []}, indent=2) + "\n",
            encoding="utf-8",
        )
        (failures_dir / f"{slug}--{marker_ts}.json").write_text(
            json.dumps({"branch": branch, "marker_timestamp": marker_ts, "failures": []}, indent=2) + "\n",
            encoding="utf-8",
        )
        _run(["git", "add", "-A"], cwd=repo)
        _run(["git", "commit", "-q", "-m", "seed retro artifacts"], cwd=repo)

        launch = _run(
            [
                str(_manager_path(repo)),
                "launch",
                "--type",
                "throwaway",
                "--slug",
                "senior-review",
                "--role",
                "senior_architect",
                "--launcher",
                "manual",
            ],
            cwd=repo,
        )
        assert launch.returncode != 0
        assert "marker head does not match current HEAD" in launch.stderr
