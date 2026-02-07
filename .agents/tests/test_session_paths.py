"""Session path migration tests for PHASE-02."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BIN_DIR = REPO_ROOT / ".agents" / "bin"
DEPLOY_SCRIPT = BIN_DIR / "deploy_agents_process.sh"
if str(BIN_DIR) not in sys.path:
    sys.path.insert(0, str(BIN_DIR))

import extract_codex_rollout as rollout_extractor  # noqa: E402
from parallelus_paths import sessions_write_root  # noqa: E402


def _run(cmd: list[str], cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(cmd, cwd=cwd, env=run_env, text=True, capture_output=True, check=False)


def _init_repo(tmp: Path, branch: str = "feature/demo") -> None:
    shutil.copytree(REPO_ROOT / ".agents", tmp / ".agents")
    slug = branch.replace("/", "-")
    notebook_dir = tmp / "docs" / "branches" / slug
    notebook_dir.mkdir(parents=True, exist_ok=True)
    (notebook_dir / "PLAN.md").write_text(f"# Branch Plan — {branch}\n", encoding="utf-8")
    (notebook_dir / "PROGRESS.md").write_text(f"# Branch Progress — {branch}\n", encoding="utf-8")

    _run(["git", "init", "-q"], cwd=tmp)
    _run(["git", "config", "user.name", "Session Paths"], cwd=tmp)
    _run(["git", "config", "user.email", "session.paths@example.com"], cwd=tmp)
    (tmp / "README.md").write_text("session-paths\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=tmp)
    _run(["git", "commit", "-q", "-m", "init"], cwd=tmp)
    _run(["git", "checkout", "-q", "-b", branch], cwd=tmp)


def _parse_export(stdout: str, key: str) -> str:
    prefix = f"export {key}="
    for line in stdout.splitlines():
        if line.startswith(prefix):
            value = line[len(prefix) :]
            if value.startswith("'") and value.endswith("'"):
                value = value[1:-1]
            return value
    raise AssertionError(f"missing export for {key}: {stdout}")


def test_session_start_writes_to_parallelus_sessions_root() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-start-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo)

        result = _run([str(repo / ".agents" / "bin" / "agents-session-start")], cwd=repo)
        assert result.returncode == 0, result.stderr

        session_id = _parse_export(result.stdout, "SESSION_ID")
        session_dir = Path(_parse_export(result.stdout, "SESSION_DIR"))

        assert session_id
        assert session_dir.is_dir()
        assert session_dir.parent.resolve() == sessions_write_root(repo).resolve()
        branch_slug = "feature-demo"
        branch_pointer = sessions_write_root(repo) / f".current-{branch_slug}"
        global_pointer = sessions_write_root(repo) / ".current"
        assert branch_pointer.read_text(encoding="utf-8").strip() == session_id
        assert global_pointer.read_text(encoding="utf-8").strip() == session_id


def test_session_logging_active_accepts_pointer_without_env() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-log-active-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/log-active"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        session_id = "20260207-log-active"
        session_root = sessions_write_root(repo)
        session_dir = session_root / session_id
        session_dir.mkdir(parents=True, exist_ok=True)
        (session_dir / "console.log").write_text("active log\n", encoding="utf-8")
        (session_root / f".current-{slug}").write_text(session_id + "\n", encoding="utf-8")

        result = _run([str(repo / ".agents" / "bin" / "agents-session-logging-active"), "--quiet"], cwd=repo)
        assert result.returncode == 0, result.stderr


def test_session_logging_active_fails_without_context() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-log-missing-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/log-missing"
        _init_repo(repo, branch=branch)

        result = _run([str(repo / ".agents" / "bin" / "agents-session-logging-active"), "--quiet"], cwd=repo)
        assert result.returncode != 0
        assert "unbound variable" not in result.stderr


def test_turn_end_reads_legacy_session_directory() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-turn-end-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/legacy-turn-end"
        _init_repo(repo, branch=branch)

        session_id = "20260207-legacy"
        legacy_session = repo / "sessions" / session_id
        legacy_session.mkdir(parents=True, exist_ok=True)
        (legacy_session / "console.log").write_text("turn-end log\n", encoding="utf-8")
        (legacy_session / "summary.md").write_text("# Session legacy\n", encoding="utf-8")
        (legacy_session / "meta.json").write_text("{\"session_id\": \"legacy\"}\n", encoding="utf-8")

        marker = repo / ".agents" / "session-required.feature-legacy-turn-end"
        if marker.exists():
            marker.unlink()

        result = _run(
            [str(repo / ".agents" / "bin" / "agents-turn-end"), "legacy checkpoint"],
            cwd=repo,
            env={"SESSION_ID": session_id, "AGENTS_RETRO_SKIP_VALIDATE": "1"},
        )
        assert result.returncode == 0, result.stderr
        assert "legacy checkpoint" in (legacy_session / "summary.md").read_text(encoding="utf-8")
        progress = repo / "docs" / "branches" / "feature-legacy-turn-end" / "PROGRESS.md"
        assert "legacy checkpoint" in progress.read_text(encoding="utf-8")


def test_turn_end_uses_runtime_session_pointer_without_env_session_id() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-pointer-turn-end-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/pointer-turn-end"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        session_id = "20260207-pointer"
        session_root = sessions_write_root(repo)
        session_dir = session_root / session_id
        session_dir.mkdir(parents=True, exist_ok=True)
        (session_dir / "console.log").write_text("pointer turn-end log\n", encoding="utf-8")
        (session_dir / "summary.md").write_text("# Session pointer\n", encoding="utf-8")
        (session_dir / "meta.json").write_text("{\"session_id\": \"pointer\"}\n", encoding="utf-8")
        (session_root / f".current-{slug}").write_text(session_id + "\n", encoding="utf-8")
        (session_root / ".current").write_text(session_id + "\n", encoding="utf-8")

        marker = repo / ".agents" / f"session-required.{slug}"
        if marker.exists():
            marker.unlink()

        result = _run(
            [str(repo / ".agents" / "bin" / "agents-turn-end"), "pointer checkpoint"],
            cwd=repo,
            env={"AGENTS_RETRO_SKIP_VALIDATE": "1"},
        )
        assert result.returncode == 0, result.stderr

        progress = repo / "docs" / "branches" / slug / "PROGRESS.md"
        assert "pointer checkpoint" in progress.read_text(encoding="utf-8")
        assert "pointer checkpoint" in (session_dir / "summary.md").read_text(encoding="utf-8")

        marker_path = repo / "docs" / "parallelus" / "self-improvement" / "markers" / f"{slug}.json"
        marker_data = json.loads(marker_path.read_text(encoding="utf-8"))
        assert marker_data.get("session_id") == session_id
        assert marker_data.get("session_console", "").startswith(".parallelus/sessions/")


def test_collect_failures_scans_new_and_legacy_session_logs() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-failures-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/failure-scan"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        marker_dir = repo / "docs" / "parallelus" / "self-improvement" / "markers"
        marker_dir.mkdir(parents=True, exist_ok=True)
        marker = marker_dir / f"{slug}.json"
        marker_ts = "2026-02-07T15:00:00Z"
        marker.write_text(json.dumps({"timestamp": marker_ts}, indent=2) + "\n", encoding="utf-8")

        new_log = repo / ".parallelus" / "sessions" / "new" / "console.log"
        new_log.parent.mkdir(parents=True, exist_ok=True)
        new_log.write_text("ERROR new session failure\n", encoding="utf-8")

        legacy_log = repo / "sessions" / "old" / "console.log"
        legacy_log.parent.mkdir(parents=True, exist_ok=True)
        legacy_log.write_text("ERROR legacy session failure\n", encoding="utf-8")

        result = _run([str(repo / ".agents" / "bin" / "collect_failures.py")], cwd=repo)
        assert result.returncode == 0, result.stderr

        rel_out = result.stdout.strip().split("wrote ", 1)[-1]
        report = json.loads((repo / rel_out).read_text(encoding="utf-8"))
        failure_sources = {
            str(Path(item.get("source", "")).resolve()) for item in report.get("failures", []) if item.get("source")
        }
        assert str(new_log.resolve()) in failure_sources
        assert str(legacy_log.resolve()) in failure_sources


def test_default_output_dir_uses_legacy_session_when_env_dir_not_set(monkeypatch) -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-output-dir-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo)

        session_id = "20260207-output"
        legacy_session = repo / "sessions" / session_id
        legacy_session.mkdir(parents=True, exist_ok=True)
        (legacy_session / "console.log").write_text("log\n", encoding="utf-8")

        monkeypatch.delenv("SESSION_DIR", raising=False)
        monkeypatch.setenv("SESSION_ID", session_id)

        assert rollout_extractor.default_output_dir(repo).resolve() == (legacy_session / "artifacts").resolve()


def test_collect_failures_dedupes_overlapping_parallelus_globs() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-failure-dedupe-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/failure-dedupe"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        marker_dir = repo / "docs" / "parallelus" / "self-improvement" / "markers"
        marker_dir.mkdir(parents=True, exist_ok=True)
        marker_ts = "2026-02-07T16:00:00Z"
        (marker_dir / f"{slug}.json").write_text(json.dumps({"timestamp": marker_ts}, indent=2) + "\n", encoding="utf-8")

        events_path = repo / ".parallelus" / "guardrails" / "runs" / "demo" / "subagent.exec_events.jsonl"
        events_path.parent.mkdir(parents=True, exist_ok=True)
        event = {"msg": {"type": "exec_command_end", "exit_code": 2, "command": "false", "stderr": "boom"}}
        events_path.write_text(json.dumps(event) + "\n", encoding="utf-8")

        result = _run([str(repo / ".agents" / "bin" / "collect_failures.py")], cwd=repo)
        assert result.returncode == 0, result.stderr

        rel_out = result.stdout.strip().split("wrote ", 1)[-1]
        report = json.loads((repo / rel_out).read_text(encoding="utf-8"))
        matching = [
            item
            for item in report.get("failures", [])
            if Path(item.get("source", "")).resolve() == events_path.resolve()
            and item.get("kind") == "exec_command_end"
        ]
        assert len(matching) == 1


def test_deploy_scaffold_gitignore_includes_parallelus_runtime_dir() -> None:
    with tempfile.TemporaryDirectory(prefix="session-path-deploy-gitignore-") as tmpdir:
        runner_repo = Path(tmpdir) / "runner-repo"
        _init_repo(runner_repo, branch="feature/deploy-runner")

        before_branch = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=runner_repo).stdout.strip()
        before_head = _run(["git", "rev-parse", "HEAD"], cwd=runner_repo).stdout.strip()

        target = Path(tmpdir) / "scaffolded"
        result = _run([str(DEPLOY_SCRIPT), str(target)], cwd=runner_repo)
        assert result.returncode == 0, result.stderr

        after_branch = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=runner_repo).stdout.strip()
        after_head = _run(["git", "rev-parse", "HEAD"], cwd=runner_repo).stdout.strip()
        assert after_branch == before_branch
        assert after_head == before_head

        entries = {
            line.strip()
            for line in (target / ".gitignore").read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
        assert ".parallelus/" in entries
