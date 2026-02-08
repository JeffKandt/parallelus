"""Custom hook contract tests for PHASE-05."""

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


def _init_repo(tmp: Path, branch: str = "feature/demo", seed_branch_notebooks: bool = True) -> None:
    shutil.copytree(REPO_ROOT / "parallelus" / "engine", tmp / "parallelus" / "engine")

    _run(["git", "init", "-q"], cwd=tmp)
    _run(["git", "config", "user.name", "Custom Hooks"], cwd=tmp)
    _run(["git", "config", "user.email", "custom.hooks@example.com"], cwd=tmp)
    (tmp / "README.md").write_text("custom-hooks\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=tmp)
    _run(["git", "commit", "-q", "-m", "init"], cwd=tmp)

    if branch:
        _run(["git", "checkout", "-q", "-b", branch], cwd=tmp)
        if seed_branch_notebooks and branch.startswith("feature/"):
            slug = branch.replace("/", "-")
            notebook_dir = tmp / "docs" / "branches" / slug
            notebook_dir.mkdir(parents=True, exist_ok=True)
            (notebook_dir / "PLAN.md").write_text(f"# Branch Plan — {branch}\n", encoding="utf-8")
            (notebook_dir / "PROGRESS.md").write_text(f"# Branch Progress — {branch}\n", encoding="utf-8")


def _parse_export(stdout: str, key: str) -> str:
    prefix = f"export {key}="
    for line in stdout.splitlines():
        if line.startswith(prefix):
            value = line[len(prefix) :]
            if value.startswith("'") and value.endswith("'"):
                return value[1:-1]
            return value
    raise AssertionError(f"missing export for {key}: {stdout}")


def _write_hook(repo: Path, event: str, body: str) -> None:
    hooks_dir = repo / "docs" / "parallelus" / "custom" / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)
    hook_path = hooks_dir / f"{event}.sh"
    hook_path.write_text(f"#!/bin/sh\nset -eu\n{body}\n", encoding="utf-8")
    hook_path.chmod(0o755)


def _write_config(repo: Path, text: str) -> None:
    config_path = repo / "docs" / "parallelus" / "custom" / "config.yaml"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(text, encoding="utf-8")


def test_custom_hooks_run_for_bootstrap_start_session_and_turn_end() -> None:
    with tempfile.TemporaryDirectory(prefix="custom-hooks-events-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo, branch="main", seed_branch_notebooks=False)

        log_file = repo / "docs" / "parallelus" / "custom" / "hook-events.log"
        for event in (
            "pre_bootstrap",
            "post_bootstrap",
            "pre_start_session",
            "post_start_session",
            "pre_turn_end",
            "post_turn_end",
        ):
            _write_hook(
                repo,
                event,
                'echo "ran:$PARALLELUS_EVENT"\n'
                'printf "%s|%s|%s|%s\\n" "$PARALLELUS_EVENT" "$PWD" "$PARALLELUS_REPO_ROOT" "$PARALLELUS_BUNDLE_ROOT" >> "$PARALLELUS_REPO_ROOT/docs/parallelus/custom/hook-events.log"',
            )

        bootstrap = _run([str(repo / "parallelus" / "engine" / "bin" / "agents-ensure-feature"), "custom-hook-events"], cwd=repo)
        assert bootstrap.returncode == 0, bootstrap.stderr
        assert "[custom-hook:pre_bootstrap] ran:pre_bootstrap" in bootstrap.stderr
        assert "[custom-hook:post_bootstrap] ran:post_bootstrap" in bootstrap.stderr

        start_session = _run([str(repo / "parallelus" / "engine" / "bin" / "agents-session-start")], cwd=repo)
        assert start_session.returncode == 0, start_session.stderr
        assert "[custom-hook:pre_start_session] ran:pre_start_session" in start_session.stderr
        assert "[custom-hook:post_start_session] ran:post_start_session" in start_session.stderr

        session_id = _parse_export(start_session.stdout, "SESSION_ID")
        session_dir = Path(_parse_export(start_session.stdout, "SESSION_DIR"))
        (session_dir / "console.log").write_text("hook test\n", encoding="utf-8")

        turn_end = _run(
            [str(repo / "parallelus" / "engine" / "bin" / "agents-turn-end"), "hook lifecycle checkpoint"],
            cwd=repo,
            env={"SESSION_ID": session_id, "AGENTS_RETRO_SKIP_VALIDATE": "1"},
        )
        assert turn_end.returncode == 0, turn_end.stderr
        assert "[custom-hook:pre_turn_end] ran:pre_turn_end" in turn_end.stderr
        assert "[custom-hook:post_turn_end] ran:post_turn_end" in turn_end.stderr

        events = [line.split("|", 1)[0] for line in log_file.read_text(encoding="utf-8").splitlines() if line.strip()]
        assert events == [
            "pre_bootstrap",
            "post_bootstrap",
            "pre_start_session",
            "post_start_session",
            "pre_turn_end",
            "post_turn_end",
        ]

        repo_root = str(repo.resolve())
        expected_bundle_root = str((repo / "parallelus").resolve())
        for line in log_file.read_text(encoding="utf-8").splitlines():
            event, cwd_value, repo_env, bundle_env = line.split("|", 3)
            assert event
            assert cwd_value == repo_root
            assert repo_env == repo_root
            assert bundle_env == expected_bundle_root


def test_pre_hook_fail_blocks_when_configured() -> None:
    with tempfile.TemporaryDirectory(prefix="custom-hooks-pre-fail-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo)

        _write_hook(repo, "pre_start_session", 'echo "pre fail"\nexit 7')
        _write_config(
            repo,
            """version: 1
hooks:
  pre_start_session:
    on_error: fail
""",
        )

        result = _run([str(repo / "parallelus" / "engine" / "bin" / "agents-session-start")], cwd=repo)
        assert result.returncode != 0
        assert "[custom-hook:pre_start_session] hook exited with code 7" in result.stderr


def test_pre_hook_warn_continues_and_post_hook_failure_warns() -> None:
    with tempfile.TemporaryDirectory(prefix="custom-hooks-pre-warn-") as tmpdir:
        repo = Path(tmpdir)
        branch = "feature/pre-warn"
        slug = branch.replace("/", "-")
        _init_repo(repo, branch=branch)

        _write_hook(repo, "pre_start_session", 'echo "pre warn"\nexit 5')
        _write_hook(repo, "post_turn_end", 'echo "post warn"\nexit 9')
        _write_config(
            repo,
            """version: 1
hooks:
  pre_start_session:
    on_error: warn
""",
        )

        start_result = _run([str(repo / "parallelus" / "engine" / "bin" / "agents-session-start")], cwd=repo)
        assert start_result.returncode == 0, start_result.stderr
        assert "[custom-hook:pre_start_session] hook exited with code 5" in start_result.stderr

        session_id = _parse_export(start_result.stdout, "SESSION_ID")
        session_dir = Path(_parse_export(start_result.stdout, "SESSION_DIR"))
        (session_dir / "console.log").write_text("warn test\n", encoding="utf-8")

        marker = repo / "parallelus" / "engine" / f"session-required.{slug}"
        if marker.exists():
            marker.unlink()

        turn_result = _run(
            [str(repo / "parallelus" / "engine" / "bin" / "agents-turn-end"), "warn checkpoint"],
            cwd=repo,
            env={"SESSION_ID": session_id, "AGENTS_RETRO_SKIP_VALIDATE": "1"},
        )
        assert turn_result.returncode == 0, turn_result.stderr
        assert "[custom-hook:post_turn_end] hook exited with code 9" in turn_result.stderr


def test_custom_hooks_disabled_and_missing_are_safe_noops() -> None:
    with tempfile.TemporaryDirectory(prefix="custom-hooks-noop-") as tmpdir:
        repo = Path(tmpdir)
        _init_repo(repo)

        disabled_repo = repo / "disabled"
        shutil.copytree(repo, disabled_repo)
        _write_hook(disabled_repo, "pre_start_session", 'echo "disabled fail"\nexit 6')
        _write_config(
            disabled_repo,
            """version: 1
enabled: false
hooks:
  pre_start_session:
    on_error: fail
""",
        )

        disabled_result = _run(
            [str(disabled_repo / "parallelus" / "engine" / "bin" / "agents-session-start")],
            cwd=disabled_repo,
        )
        assert disabled_result.returncode == 0, disabled_result.stderr
        assert "disabled fail" not in disabled_result.stderr

        missing_repo = repo / "missing"
        shutil.copytree(repo, missing_repo)
        missing_result = _run(
            [str(missing_repo / "parallelus" / "engine" / "bin" / "agents-session-start")],
            cwd=missing_repo,
        )
        assert missing_result.returncode == 0, missing_result.stderr
        assert "[custom-hook:" not in missing_result.stderr
