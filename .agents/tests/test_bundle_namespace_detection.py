"""Tests for deploy bundle namespace detection precedence and overrides."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / ".agents" / "bin" / "deploy_agents_process.sh"


def _run_detect(target_dir: Path, env: dict[str, str] | None = None) -> tuple[subprocess.CompletedProcess[str], dict[str, str]]:
    run_env = os.environ.copy()
    if env:
        run_env.update(env)

    result = subprocess.run(
        [str(SCRIPT), "--detect-namespace", str(target_dir)],
        cwd=REPO_ROOT,
        env=run_env,
        text=True,
        capture_output=True,
        check=False,
    )
    parsed: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        parsed[key] = value
    return result, parsed


def _write_manifest(root: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    payload = {
        "bundle_id": "parallelus.bundle.v1",
        "layout_version": 1,
        "upstream_repo": "https://github.com/parallelus/process.git",
        "bundle_version": "deadbeef",
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
        path.write_text("stub\n", encoding="utf-8")

    (root / "AGENTS.md").write_text("# Parallelus Agent Core Guardrails\n", encoding="utf-8")
    (root / "Makefile").write_text("help:\n\t@echo \"make start_session\"\n", encoding="utf-8")


def test_detection_prefers_parallelus_when_both_manifests_are_valid() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        _write_manifest(target / "parallelus")
        _write_manifest(target / "vendor" / "parallelus")

        result, parsed = _run_detect(target)

    assert result.returncode == 0, result.stderr
    assert parsed["NAMESPACE_DECISION"] == "parallelus"
    assert parsed["NAMESPACE_REASON"] == "sentinel_parallelus_preferred_dual"


def test_detection_uses_vendor_manifest_when_parallelus_manifest_missing() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        _write_manifest(target / "vendor" / "parallelus")

        result, parsed = _run_detect(target)

    assert result.returncode == 0, result.stderr
    assert parsed["NAMESPACE_DECISION"] == "vendor/parallelus"
    assert parsed["NAMESPACE_REASON"] == "sentinel_vendor"


def test_detection_legacy_fallback_without_manifests() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        _write_legacy_fingerprints(target)

        result, parsed = _run_detect(target)

    assert result.returncode == 0, result.stderr
    assert parsed["NAMESPACE_DECISION"] == "parallelus"
    assert parsed["NAMESPACE_REASON"] == "legacy_parallelus"
    assert parsed["LEGACY_STRONG_COUNT"] == "3"
    assert parsed["LEGACY_CONTEXT_COUNT"] == "2"


def test_detection_skips_malformed_parallelus_manifest() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        bad_manifest = target / "parallelus" / ".parallelus-bundle.json"
        bad_manifest.parent.mkdir(parents=True, exist_ok=True)
        bad_manifest.write_text("{bad json\n", encoding="utf-8")
        _write_manifest(target / "vendor" / "parallelus")

        result, parsed = _run_detect(target)

    assert result.returncode == 0, result.stderr
    assert parsed["NAMESPACE_DECISION"] == "vendor/parallelus"
    assert parsed["PARALLELUS_SENTINEL_STATUS"].startswith("invalid:")
    assert parsed["NAMESPACE_REASON"] == "sentinel_vendor"


def test_detection_override_force_in_place() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        _write_manifest(target / "vendor" / "parallelus")

        result, parsed = _run_detect(target, env={"PARALLELUS_UPGRADE_FORCE_IN_PLACE": "1"})

    assert result.returncode == 0, result.stderr
    assert parsed["NAMESPACE_DECISION"] == "parallelus"
    assert parsed["NAMESPACE_REASON"] == "override_force_in_place"
    assert parsed["NAMESPACE_OVERRIDE_USED"] == "1"


def test_detection_override_force_vendor() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        _write_legacy_fingerprints(target)

        result, parsed = _run_detect(target, env={"PARALLELUS_UPGRADE_FORCE_VENDOR": "1"})

    assert result.returncode == 0, result.stderr
    assert parsed["NAMESPACE_DECISION"] == "vendor/parallelus"
    assert parsed["NAMESPACE_REASON"] == "override_force_vendor"
    assert parsed["NAMESPACE_OVERRIDE_USED"] == "1"


def test_detection_conflicting_overrides_fail_fast() -> None:
    with tempfile.TemporaryDirectory(prefix="namespace-detect-") as tmp:
        target = Path(tmp)
        result, _ = _run_detect(
            target,
            env={
                "PARALLELUS_UPGRADE_FORCE_IN_PLACE": "1",
                "PARALLELUS_UPGRADE_FORCE_VENDOR": "1",
            },
        )

    assert result.returncode != 0
    assert "cannot both be set" in result.stderr
