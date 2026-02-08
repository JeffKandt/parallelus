#!/usr/bin/env python3
"""Commit-aware local retrospective auditor."""

from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from parallelus_docs_paths import failures_write_dir, marker_read_path, reports_write_dir


def git_root() -> Path:
    out = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True)
    return Path(out.strip())


def current_branch() -> str:
    out = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"], text=True)
    branch = out.strip()
    if branch in {"", "HEAD"}:
        raise SystemExit("retro_audit_local: detached HEAD not supported")
    return branch


def current_head() -> str:
    out = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True)
    return out.strip()


def _sanitize_issue_id(text: str, idx: int) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    if not cleaned:
        cleaned = "issue"
    return f"{cleaned}-{idx}"


def _build_issues(failures: list[dict], warnings: list[str]) -> list[dict]:
    issues: list[dict] = []
    for idx, item in enumerate(failures, start=1):
        kind = str(item.get("kind") or "failure")
        source = str(item.get("source") or "unknown-source")
        command = str(item.get("command") or "")
        exit_code = item.get("exit_code")
        excerpt = str(item.get("excerpt") or item.get("error") or item.get("stderr") or "")
        details = command or excerpt or "no extra details"
        if len(details) > 240:
            details = details[:237] + "..."
        issues.append(
            {
                "id": _sanitize_issue_id(kind, idx),
                "root_cause": f"Tool execution recorded a '{kind}' event while collecting retrospective evidence.",
                "mitigation": "Inspect the failing command/log source and re-run the failing step on the current commit.",
                "prevention": "Keep the retrospective preflight serialized and add/maintain regression coverage for recurring failures.",
                "evidence": f"source={source}; exit_code={exit_code}; details={details}",
            }
        )

    for idx, warning in enumerate(warnings, start=1):
        issues.append(
            {
                "id": _sanitize_issue_id("warning", idx),
                "root_cause": "Retrospective evidence collection produced a warning.",
                "mitigation": "Inspect the warning source and refresh the failures summary for the current marker.",
                "prevention": "Keep evidence sources deterministic and avoid stale or empty session artifacts.",
                "evidence": str(warning),
            }
        )
    return issues


def main() -> None:
    repo = git_root()
    branch = current_branch()
    head = current_head()
    slugged = branch.replace("/", "-")

    marker_path = marker_read_path(repo, slugged)
    if not marker_path.exists():
        raise SystemExit(
            "retro_audit_local: marker not found; run parallelus/engine/bin/retro-marker first"
        )
    marker = json.loads(marker_path.read_text(encoding="utf-8"))
    marker_ts = marker.get("timestamp")
    marker_head = marker.get("head")
    if not marker_ts:
        raise SystemExit(f"retro_audit_local: marker {marker_path} missing timestamp")
    if marker_head and marker_head != head:
        raise SystemExit(
            "retro_audit_local: marker head mismatch "
            f"(marker={marker_head}, current={head}); rerun parallelus/engine/bin/retro-marker"
        )

    marker_root = marker_path.parent.parent
    failures_path = marker_root / "failures" / f"{slugged}--{marker_ts}.json"
    if not failures_path.exists():
        fallback = failures_write_dir(repo) / f"{slugged}--{marker_ts}.json"
        failures_path = fallback if fallback.exists() else failures_path
    if not failures_path.exists():
        raise SystemExit(
            "retro_audit_local: marker-matched failures summary not found; "
            "run parallelus/engine/bin/collect_failures.py after parallelus/engine/bin/retro-marker"
        )

    failures_data = json.loads(failures_path.read_text(encoding="utf-8"))
    failures = failures_data.get("failures") or []
    warnings = failures_data.get("warnings") or []
    issues = _build_issues(failures, warnings)

    if issues:
        summary = (
            "Retrospective preflight found evidence issues in the marker-matched "
            "failures summary; resolve before senior review."
        )
        follow_ups = [
            "Address each marker-matched failures/warnings issue and regenerate retrospective artifacts.",
            "Re-run the serialized preflight pipeline before launching senior review.",
        ]
    else:
        summary = (
            "No blocking issues detected. Marker and marker-matched failures summary "
            "align to the current commit."
        )
        follow_ups = [
            "Keep preflight serialized: retro-marker -> collect_failures -> retro_audit_local.",
            "Re-run preflight whenever HEAD changes before senior review launch.",
        ]

    report = {
        "branch": branch,
        "marker_timestamp": marker_ts,
        "summary": summary,
        "issues": issues,
        "follow_ups": follow_ups,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "local_commit_aware",
    }

    report_path = reports_write_dir(repo) / f"{slugged}--{marker_ts}.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"retro_audit_local: wrote {report_path.relative_to(repo)}",
        flush=True,
    )


if __name__ == "__main__":
    main()
