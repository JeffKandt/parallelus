"""PHASE-06 migration tests for deploy_agents_process overlay upgrades."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "parallelus" / "engine" / "bin" / "deploy_agents_process.sh"


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    for key in ("PARALLELUS_UPGRADE_FORCE_IN_PLACE", "PARALLELUS_UPGRADE_FORCE_VENDOR"):
        env.pop(key, None)
    return subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True, check=False)


def _init_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _run(["git", "init", "-q"], cwd=path)
    _run(["git", "config", "user.name", "Upgrade Tests"], cwd=path)
    _run(["git", "config", "user.email", "upgrade.tests@example.com"], cwd=path)
    (path / "README.md").write_text("upgrade tests\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=path)
    _run(["git", "commit", "-q", "-m", "init"], cwd=path)
    _run(["git", "checkout", "-q", "-b", "feature/upgrade-tests"], cwd=path)


def _commit_all(path: Path, message: str) -> None:
    _run(["git", "add", "."], cwd=path)
    result = _run(["git", "commit", "-q", "-m", message], cwd=path)
    if result.returncode != 0 and "nothing to commit" not in (result.stdout + result.stderr).lower():
        raise AssertionError(result.stderr or result.stdout)


def _write_manifest(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    payload = {
        "bundle_id": "parallelus.bundle.v1",
        "layout_version": 1,
        "upstream_repo": "https://github.com/parallelus/parallelus.git",
        "bundle_version": "abcdef123456",
        "installed_on": "2026-02-07T00:00:00Z",
        "managed_paths": ["engine", "manuals"],
    }
    (root / ".parallelus-bundle.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def _write_legacy_fingerprints(root: Path) -> None:
    required = [
        ".agents/bin/agents-session-start",
        ".agents/bin/agents-ensure-feature",
        ".agents/hooks/pre-commit",
    ]
    for rel in required:
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("legacy\n", encoding="utf-8")

    (root / ".agents/prompts/agent_roles/senior_architect.md").parent.mkdir(parents=True, exist_ok=True)
    (root / ".agents/prompts/agent_roles/senior_architect.md").write_text("prompt\n", encoding="utf-8")
    (root / "AGENTS.md").write_text("# Parallelus Agent Core Guardrails\n", encoding="utf-8")
    (root / "Makefile").write_text("help:\n\t@echo \"make start_session\"\n", encoding="utf-8")


def _latest_report(repo: Path) -> dict:
    reports = sorted((repo / ".parallelus" / "upgrade-reports").glob("upgrade-*.json"))
    assert reports, "expected at least one migration report"
    return json.loads(reports[-1].read_text(encoding="utf-8"))


def _extract_stdout_report(stdout: str) -> dict:
    begin = "MIGRATION_REPORT_JSON_BEGIN"
    end = "MIGRATION_REPORT_JSON_END"
    assert begin in stdout
    assert end in stdout
    payload = stdout.split(begin, 1)[1].split(end, 1)[0].strip()
    return json.loads(payload)


def test_overlay_upgrade_migrates_legacy_layout_and_writes_report() -> None:
    with tempfile.TemporaryDirectory(prefix="upgrade-legacy-") as tmp:
        repo = Path(tmp) / "repo"
        _init_repo(repo)
        _write_legacy_fingerprints(repo)

        (repo / "docs/agents/legacy-manual.md").parent.mkdir(parents=True, exist_ok=True)
        (repo / "docs/agents/legacy-manual.md").write_text("legacy manual\n", encoding="utf-8")
        (repo / "docs/plans/feature-legacy.md").parent.mkdir(parents=True, exist_ok=True)
        (repo / "docs/plans/feature-legacy.md").write_text("# Legacy plan\n", encoding="utf-8")
        (repo / "docs/progress/feature-legacy.md").parent.mkdir(parents=True, exist_ok=True)
        (repo / "docs/progress/feature-legacy.md").write_text("# Legacy progress\n", encoding="utf-8")
        (repo / "docs/reviews/legacy-review.md").parent.mkdir(parents=True, exist_ok=True)
        (repo / "docs/reviews/legacy-review.md").write_text("review\n", encoding="utf-8")
        (repo / "docs/self-improvement/markers/feature-legacy.json").parent.mkdir(parents=True, exist_ok=True)
        (repo / "docs/self-improvement/markers/feature-legacy.json").write_text('{"timestamp":"2026-02-07T00:00:00Z"}\n', encoding="utf-8")
        (repo / "sessions/2026-legacy/console.log").parent.mkdir(parents=True, exist_ok=True)
        (repo / "sessions/2026-legacy/console.log").write_text("legacy session log\n", encoding="utf-8")
        _commit_all(repo, "legacy layout")

        result = _run([str(SCRIPT), "--overlay-upgrade", str(repo)], cwd=REPO_ROOT)
        assert result.returncode == 0, result.stderr

        report = _latest_report(repo)
        assert report["host_state_classification"] == "legacy_deployment"
        assert report["bundle_root"] == "parallelus"

        sentinel = repo / "parallelus/.parallelus-bundle.json"
        sentinel_data = json.loads(sentinel.read_text(encoding="utf-8"))
        assert sentinel_data["bundle_id"] == "parallelus.bundle.v1"

        assert (repo / "parallelus/manuals/legacy-manual.md").is_file()
        assert (repo / "docs/branches/feature-legacy/PLAN.md").is_file()
        assert (repo / "docs/branches/feature-legacy/PROGRESS.md").is_file()
        assert (repo / "docs/parallelus/reviews/legacy-review.md").is_file()
        assert (repo / "docs/parallelus/self-improvement/markers/feature-legacy.json").is_file()
        assert (repo / ".parallelus/sessions/2026-legacy/console.log").is_file()

        # Upgrade migration is non-destructive by design.
        assert (repo / ".agents").exists()
        assert (repo / "docs/plans").exists()
        assert (repo / "sessions").exists()


def test_overlay_upgrade_classifies_mixed_interrupted_state() -> None:
    with tempfile.TemporaryDirectory(prefix="upgrade-mixed-") as tmp:
        repo = Path(tmp) / "repo"
        _init_repo(repo)
        _write_legacy_fingerprints(repo)
        (repo / "parallelus/engine/bin").mkdir(parents=True, exist_ok=True)
        (repo / "parallelus/engine/bin/agents-session-start").write_text("stub\n", encoding="utf-8")
        _commit_all(repo, "mixed layout")

        result = _run([str(SCRIPT), "--overlay-upgrade", str(repo)], cwd=REPO_ROOT)
        assert result.returncode == 0, result.stderr

        report = _latest_report(repo)
        assert report["host_state_classification"] == "mixed_or_interrupted"
        assert report["namespace_detection"]["decision"] == "parallelus"


def test_vendor_namespace_upgrade_keeps_bootstrap_entrypoints_working() -> None:
    with tempfile.TemporaryDirectory(prefix="upgrade-vendor-") as tmp:
        repo = Path(tmp) / "repo"
        _init_repo(repo)
        _commit_all(repo, "baseline")

        result = _run([str(SCRIPT), "--overlay-upgrade", str(repo)], cwd=REPO_ROOT)
        assert result.returncode == 0, result.stderr

        report = _latest_report(repo)
        assert report["namespace_detection"]["decision"] == "vendor/parallelus"
        _commit_all(repo, "vendor upgrade")

        start_result = _run(["make", "start_session"], cwd=repo)
        assert start_result.returncode == 0, start_result.stderr

        bootstrap_result = _run(["make", "bootstrap", "slug=vendor-ready"], cwd=repo)
        assert bootstrap_result.returncode == 0, bootstrap_result.stderr
        branch = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo).stdout.strip()
        assert branch == "feature/vendor-ready"


def test_overlay_upgrade_rerun_on_reorg_repo_is_safe() -> None:
    with tempfile.TemporaryDirectory(prefix="upgrade-reorg-") as tmp:
        repo = Path(tmp) / "repo"
        _init_repo(repo)

        _write_manifest(repo / "parallelus")
        (repo / "parallelus/engine/bin").mkdir(parents=True, exist_ok=True)
        (repo / "parallelus/engine/bin/agents-session-start").write_text("stub\n", encoding="utf-8")
        (repo / "parallelus/manuals").mkdir(parents=True, exist_ok=True)
        _commit_all(repo, "reorg baseline")

        first = _run([str(SCRIPT), "--overlay-upgrade", str(repo)], cwd=REPO_ROOT)
        assert first.returncode == 0, first.stderr
        _commit_all(repo, "post-upgrade snapshot")
        second = _run([str(SCRIPT), "--overlay-upgrade", str(repo)], cwd=REPO_ROOT)
        assert second.returncode == 0, second.stderr

        report = _latest_report(repo)
        assert report["host_state_classification"] == "reorg_deployment"
        assert not (repo / "vendor/parallelus").exists()
        assert (repo / "parallelus/.parallelus-bundle.json").is_file()


def test_overlay_upgrade_dry_run_reports_without_mutating_files() -> None:
    with tempfile.TemporaryDirectory(prefix="upgrade-dry-run-") as tmp:
        repo = Path(tmp) / "repo"
        _init_repo(repo)
        _write_legacy_fingerprints(repo)
        (repo / "sessions/legacy/console.log").parent.mkdir(parents=True, exist_ok=True)
        (repo / "sessions/legacy/console.log").write_text("legacy\n", encoding="utf-8")
        _commit_all(repo, "legacy dry-run")

        result = _run([str(SCRIPT), "--overlay-upgrade", "--dry-run", str(repo)], cwd=REPO_ROOT)
        assert result.returncode == 0, result.stderr

        report = _extract_stdout_report(result.stdout)
        assert report["dry_run"] is True
        assert any(step["status"] == "planned" for step in report["steps"])
        assert not (repo / "parallelus/.parallelus-bundle.json").exists()
        assert not (repo / ".parallelus/upgrade-reports").exists()
