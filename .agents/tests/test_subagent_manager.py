"""Regression tests for subagent_manager deliverable handling."""

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


def _init_repo(tmp: Path, branch: str = "feature/demo") -> None:
    shutil.copytree(REPO_ROOT / ".agents", tmp / ".agents")
    (tmp / "docs" / "agents").mkdir(parents=True, exist_ok=True)
    (tmp / "docs" / "reviews").mkdir(parents=True, exist_ok=True)

    _run(["git", "init", "-q"], cwd=tmp)
    _run(["git", "config", "user.name", "Subagent Tests"], cwd=tmp)
    _run(["git", "config", "user.email", "subagent.tests@example.com"], cwd=tmp)
    (tmp / "README.md").write_text("subagent-manager-tests\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=tmp)
    _run(["git", "commit", "-q", "-m", "init"], cwd=tmp)
    _run(["git", "checkout", "-q", "-b", branch], cwd=tmp)


def _registry_path(repo: Path) -> Path:
    return repo / "docs" / "agents" / "subagent-registry.json"


def _manager_path(repo: Path) -> Path:
    return repo / ".agents" / "bin" / "subagent_manager.sh"


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
        review_rel = f"docs/reviews/{branch_slug}-2026-02-07.md"
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
                                "source_glob": f"docs/reviews/{branch_slug}-*.md",
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
                                "source_glob": "docs/reviews/feature-cleanup-*.md",
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
