#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

REDACTION_PATTERNS = [
    (re.compile(r"-----BEGIN [A-Z ]+PRIVATE KEY-----[\s\S]+?-----END [A-Z ]+PRIVATE KEY-----"), "[REDACTED_PRIVATE_KEY]"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "[REDACTED_AWS_ACCESS_KEY]"),
    (re.compile(r"\bASIA[0-9A-Z]{16}\b"), "[REDACTED_AWS_SESSION_KEY]"),
    (re.compile(r"(?i)(aws[^\n]{0,20}?(secret|access)?_?key)\s*[:=]\s*[A-Za-z0-9/+=]{20,}"), r"\1=[REDACTED_AWS_SECRET]"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"), "[REDACTED_GH_TOKEN]"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9-]+\b"), "[REDACTED_SLACK_TOKEN]"),
    (re.compile(r"\bsk-[A-Za-z0-9]{20,}\b"), "[REDACTED_API_KEY]"),
    (re.compile(r"(?i)(bearer\s+)[A-Za-z0-9\-._~+/]+=*"), r"\1[REDACTED_TOKEN]"),
    (re.compile(r"(?i)\b(token|api[-_]?key|secret|password|passwd|pwd)\b\s*[:=]\s*[^\s'\"]+"), r"\1=[REDACTED]"),
]


def redact_text(value: str) -> str:
    text = value
    for pattern, replacement in REDACTION_PATTERNS:
        text = pattern.sub(replacement, text)
    return text


def redact_obj(obj):
    if isinstance(obj, str):
        return redact_text(obj)
    if isinstance(obj, list):
        return [redact_obj(item) for item in obj]
    if isinstance(obj, dict):
        return {k: redact_obj(v) for k, v in obj.items()}
    return obj


def find_rollouts(root: Path, nonce: str) -> list:
    rollouts = sorted(root.glob("**/rollout-*.jsonl"))
    matched = []
    for path in rollouts:
        try:
            with path.open("r", encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    if nonce in line:
                        matched.append(path)
                        break
        except FileNotFoundError:
            continue
    return matched


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract and redact Codex rollout logs containing a nonce.")
    parser.add_argument("--nonce", required=True, help="Nonce string to locate in rollout JSONL files.")
    parser.add_argument(
        "--sessions-root",
        default=str(Path.home() / ".codex" / "sessions"),
        help="Root of Codex sessions directory (default: ~/.codex/sessions)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output path for redacted JSONL (default: docs/guardrails/runs/codex-rollout-<file>.jsonl)",
    )
    args = parser.parse_args()

    root = Path(args.sessions_root).expanduser()
    matched = find_rollouts(root, args.nonce)
    if not matched:
        raise SystemExit("extract_codex_rollout: no rollout files contained the nonce")

    matched.sort(key=lambda p: p.stat().st_mtime)
    rollout = matched[-1]

    repo_root = Path(__file__).resolve().parents[2]
    out_dir = repo_root / "docs" / "guardrails" / "runs"
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.output:
        out_path = Path(args.output)
    else:
        out_path = out_dir / f"codex-rollout-{rollout.stem}.jsonl"

    with rollout.open("r", encoding="utf-8", errors="ignore") as src, out_path.open("w", encoding="utf-8") as dst:
        for line in src:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                dst.write(redact_text(line) + "\n")
                continue
            redacted = redact_obj(obj)
            dst.write(json.dumps(redacted, ensure_ascii=True) + "\n")

    print(str(out_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
