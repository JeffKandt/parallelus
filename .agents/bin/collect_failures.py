#!/usr/bin/env python3
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def git_root() -> Path:
    out = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True)
    return Path(out.strip())


def current_branch() -> str:
    out = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"], text=True)
    branch = out.strip()
    if branch in {"HEAD", ""}:
        raise SystemExit("collect_failures: detached HEAD not supported")
    return branch


def load_marker(repo: Path, slugged: str) -> dict:
    marker_path = repo / "docs" / "self-improvement" / "markers" / f"{slugged}.json"
    if not marker_path.exists():
        raise SystemExit(
            "collect_failures: marker not found; run make turn_end before collecting failures"
        )
    try:
        return json.loads(marker_path.read_text())
    except Exception as exc:
        raise SystemExit(f"collect_failures: unable to parse {marker_path}: {exc}")


def iter_jsonl(path: Path):
    try:
        with path.open("r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        return


def scan_exec_events(path: Path, failures: list, warnings: list) -> None:
    for event in iter_jsonl(path):
        msg = event.get("msg") or event.get("payload") or event
        msg_type = msg.get("type") if isinstance(msg, dict) else None
        if msg_type == "exec_command_end":
            exit_code = msg.get("exit_code")
            if exit_code is not None and int(exit_code) != 0:
                failures.append(
                    {
                        "source": str(path),
                        "kind": "exec_command_end",
                        "exit_code": exit_code,
                        "command": msg.get("command") or msg.get("argv"),
                        "stderr": msg.get("stderr"),
                    }
                )
        elif msg_type and "error" in msg_type:
            failures.append(
                {
                    "source": str(path),
                    "kind": msg_type,
                    "error": msg.get("error") or msg.get("message") or msg,
                }
            )
        elif isinstance(msg, dict) and msg.get("error"):
            failures.append(
                {
                    "source": str(path),
                    "kind": msg.get("type") or "error",
                    "error": msg.get("error"),
                }
            )
    if path.exists() and path.stat().st_size == 0:
        warnings.append(f"{path} is empty")


def scan_text_log(path: Path, failures: list, warnings: list) -> None:
    if not path.exists():
        return
    patterns = [
        re.compile(r"\bERROR\b", re.IGNORECASE),
        re.compile(r"\bTraceback\b"),
        re.compile(r"exit code\s+([1-9][0-9]*)", re.IGNORECASE),
    ]
    hits = 0
    with path.open("r", encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            if any(p.search(line) for p in patterns):
                failures.append(
                    {
                        "source": str(path),
                        "kind": "unstructured_log",
                        "excerpt": line.strip()[:300],
                    }
                )
                hits += 1
                if hits >= 50:
                    warnings.append(f"{path} produced many matches; truncated to 50")
                    break


def main() -> None:
    repo = git_root()
    branch = current_branch()
    slugged = branch.replace("/", "-")
    marker = load_marker(repo, slugged)
    marker_ts = marker.get("timestamp")
    if not marker_ts:
        raise SystemExit("collect_failures: marker missing timestamp")

    failures_dir = repo / "docs" / "self-improvement" / "failures"
    failures_dir.mkdir(parents=True, exist_ok=True)
    out_path = failures_dir / f"{slugged}--{marker_ts}.json"

    failures = []
    warnings = []
    sources = []

    candidates = []
    candidates += list(repo.glob("sessions/*/console.log"))
    candidates += list(repo.glob(".parallelus/**/subagent.exec_events.jsonl"))
    candidates += list(repo.glob(".parallelus/**/subagent.session.jsonl"))
    candidates += list(repo.glob("docs/guardrails/runs/**/session.jsonl"))
    candidates += list(repo.glob("docs/guardrails/runs/**/subagent.exec_events.jsonl"))

    for path in candidates:
        sources.append(str(path))
        if path.suffix == ".jsonl":
            scan_exec_events(path, failures, warnings)
        else:
            scan_text_log(path, failures, warnings)

    data = {
        "branch": branch,
        "marker_timestamp": marker_ts,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sources": sources,
        "failures": failures,
        "warnings": warnings,
    }
    out_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"collect_failures: wrote {out_path.relative_to(repo)}", flush=True)


if __name__ == "__main__":
    main()
