#!/usr/bin/env python3
import argparse
import json
import os
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


def default_output_dir(repo_root: Path) -> Path:
    session_dir = Path(os.environ.get("SESSION_DIR", "")).expanduser()
    if session_dir and (session_dir / "console.log").exists():
        return session_dir / "artifacts"
    return repo_root / "sessions" / "extracted"


def render_markdown(events: list, source_path: Path) -> str:
    lines = []
    lines.append("# Codex Rollout Transcript")
    lines.append("")
    lines.append(f"- Source: {source_path}")
    lines.append(f"- Events: {len(events)}")
    lines.append("")
    for ev in events:
        etype = ev.get("type") or ev.get("event") or ev.get("kind")
        msg = ev.get("msg") or ev.get("message") or ev.get("payload")
        if not etype and isinstance(msg, dict):
            etype = msg.get("type") or msg.get("event")
        if etype == "token_count":
            continue
        if etype == "turn_context":
            cwd = ev.get("cwd") or (msg.get("cwd") if isinstance(msg, dict) else None)
            if cwd:
                lines.append(f"- [context] cwd: `{cwd}`")
            continue
        if etype == "function_call":
            name = ev.get("name") or (msg.get("name") if isinstance(msg, dict) else None)
            args = ev.get("arguments") or (msg.get("arguments") if isinstance(msg, dict) else None)
            snippet = redact_text(str(args))[:400] if args else ""
            lines.append(f"- [call] `{name}` {snippet}")
            continue
        if etype == "function_call_output":
            output = ev.get("output") or (msg.get("output") if isinstance(msg, dict) else None)
            snippet = redact_text(str(output))[:400] if output else ""
            lines.append(f"- [output] {snippet}")
            continue
        if etype in {"message", "agent_message"}:
            content = ev.get("message") or ev.get("content") or msg
            if isinstance(content, list):
                content = " ".join(str(item) for item in content)
            snippet = redact_text(str(content))[:400] if content else ""
            lines.append(f"- [message] {snippet}")
            continue
        if etype:
            snippet = redact_text(str(msg))[:240] if msg else ""
            lines.append(f"- [{etype}] {snippet}")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract and redact Codex rollout logs containing a nonce.")
    parser.add_argument("--nonce", required=True, help="Nonce string to locate in rollout JSONL files.")
    parser.add_argument(
        "--sessions-root",
        default=str(Path.home() / ".codex" / "sessions"),
        help="Root of Codex sessions directory (default: ~/.codex/sessions)",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Directory for redacted outputs (default: sessions/<ID>/artifacts or sessions/extracted)",
    )
    parser.add_argument(
        "--output-jsonl",
        default=None,
        help="Explicit output path for redacted JSONL (overrides --output-dir)",
    )
    parser.add_argument(
        "--output-md",
        default=None,
        help="Explicit output path for Markdown transcript (overrides --output-dir)",
    )
    args = parser.parse_args()

    root = Path(args.sessions_root).expanduser()
    matched = find_rollouts(root, args.nonce)
    if not matched:
        raise SystemExit("extract_codex_rollout: no rollout files contained the nonce")

    matched.sort(key=lambda p: p.stat().st_mtime)
    rollout = matched[-1]

    repo_root = Path(__file__).resolve().parents[2]
    if args.output_dir:
        out_dir = Path(args.output_dir).expanduser()
    else:
        out_dir = default_output_dir(repo_root)
    out_dir = out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.output_jsonl:
        out_jsonl = Path(args.output_jsonl)
    else:
        out_jsonl = out_dir / f"codex-rollout-{rollout.stem}.jsonl"
    if args.output_md:
        out_md = Path(args.output_md)
    else:
        out_md = out_dir / f"codex-rollout-{rollout.stem}.md"

    events = []
    with rollout.open("r", encoding="utf-8", errors="ignore") as src, out_jsonl.open("w", encoding="utf-8") as dst:
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
            events.append(redacted)
            dst.write(json.dumps(redacted, ensure_ascii=True) + "\n")

    out_md.write_text(render_markdown(events, rollout), encoding="utf-8")

    print(str(out_jsonl.resolve()))
    print(str(out_md.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
