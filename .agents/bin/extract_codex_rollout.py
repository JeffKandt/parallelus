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
    def fmt_time(ev_obj) -> str:
        for key in ("timestamp", "time", "ts", "created_at"):
            value = ev_obj.get(key)
            if value:
                return f"{value} "
        return ""

    def extract_text(value):
        if isinstance(value, dict):
            if "text" in value:
                return str(value["text"])
            if "summary" in value:
                return extract_text(value["summary"])
            if "content" in value:
                return extract_text(value["content"])
            if "content" in value:
                return extract_text(value["content"])
        if isinstance(value, list):
            parts = []
            for item in value:
                parts.append(extract_text(item))
            return " ".join(part for part in parts if part)
        if value is None:
            return ""
        return str(value)

    def extract_response_text(ev_obj) -> str:
        def pull_content(container):
            if not isinstance(container, dict):
                return ""
            content = container.get("content")
            if isinstance(content, list):
                parts = []
                for item in content:
                    if isinstance(item, dict) and item.get("type") in {"input_text", "output_text", "summary_text"}:
                        parts.append(str(item.get("text") or ""))
                return "\n".join(part for part in parts if part)
            if isinstance(content, dict) and content.get("type") in {"input_text", "output_text", "summary_text"}:
                return str(content.get("text") or "")
            summary = container.get("summary")
            if isinstance(summary, list):
                parts = []
                for item in summary:
                    if isinstance(item, dict) and item.get("type") in {"summary_text", "output_text"}:
                        parts.append(str(item.get("text") or ""))
                return "\n".join(part for part in parts if part)
            return ""

        payload = ev_obj.get("payload")
        if isinstance(payload, dict):
            text = pull_content(payload)
            if text:
                return text
        return pull_content(ev_obj)

    def render_text_block(text: str) -> list:
        if not text:
            return []
        text = text.replace("\\n", "\n").replace("\\t", "\t")
        lines = []
        for line in text.splitlines():
            if line:
                lines.append(f"  {line}")
            else:
                lines.append("  ")
        return lines

    lines = []
    lines.append("# Codex Rollout Transcript")
    lines.append("")
    lines.append(f"- Source: {source_path}")
    lines.append(f"- Events: {len(events)}")
    lines.append("")

    def dump_json(obj) -> str:
        return json.dumps(obj, ensure_ascii=True, indent=2, sort_keys=True)

    for ev in events:
        etype = ev.get("type") or ev.get("event") or ev.get("kind")
        msg = ev.get("msg") or ev.get("message") or ev.get("payload")
        if not etype and isinstance(msg, dict):
            etype = msg.get("type") or msg.get("event")

        if etype == "token_count":
            continue

        prefix = fmt_time(ev)

        if etype == "turn_context":
            cwd = ev.get("cwd") or (msg.get("cwd") if isinstance(msg, dict) else None)
            if cwd:
                lines.append(f"- {prefix}[context] cwd: `{cwd}`")
            continue

        if etype == "session_meta":
            meta = ev.get("payload") if isinstance(ev.get("payload"), dict) else ev
            lines.append(f"- {prefix}[session_meta]")
            for key in ("id", "timestamp", "cwd", "originator", "cli_version", "source", "model_provider"):
                value = meta.get(key) if isinstance(meta, dict) else None
                if value:
                    lines.append(f"  - {key}: {redact_text(str(value))}")
            base_text = ""
            if isinstance(meta, dict):
                base = meta.get("base_instructions")
                if isinstance(base, dict):
                    base_text = base.get("text") or ""
            if base_text:
                lines.append("  - base_instructions:")
                lines.extend(render_text_block(redact_text(base_text)))
            else:
                lines.append("```json")
                lines.append(dump_json(ev))
                lines.append("```")
            continue

        if etype == "event_msg":
            continue

        if etype == "response_item":
            payload = ev.get("payload") if isinstance(ev.get("payload"), dict) else {}
            name = payload.get("name") or ev.get("name")
            args = payload.get("arguments") or ev.get("arguments")
            output = payload.get("output") if "output" in payload else ev.get("output")
            encrypted = payload.get("encrypted_content") if isinstance(payload, dict) else None
            if name or args:
                lines.append(f"- {prefix}[call] `{name}`")
                if args:
                    lines.append("  - arguments:")
                    lines.append("    ```")
                    for line in redact_text(extract_text(args)).splitlines() or [""]:
                        lines.append(f"    {line}")
                    lines.append("    ```")
            elif output is not None:
                lines.append(f"- {prefix}[output]")
                lines.append("  ```")
                for line in redact_text(extract_text(output)).splitlines() or [""]:
                    lines.append(f"  {line}")
                lines.append("  ```")
            else:
                text = extract_response_text(ev)
                if text:
                    lines.append(f"- {prefix}[response_item]")
                    lines.extend(render_text_block(redact_text(text)))
                elif encrypted:
                    lines.append(f"- {prefix}[response_item] (encrypted content omitted)")
                else:
                    lines.append(f"- {prefix}[response_item]")
                    lines.append("```json")
                    lines.append(dump_json(ev))
                    lines.append("```")
            continue

        if etype == "function_call":
            name = ev.get("name") or (msg.get("name") if isinstance(msg, dict) else None)
            args = ev.get("arguments") or (msg.get("arguments") if isinstance(msg, dict) else None)
            parsed_args = None
            if isinstance(args, str):
                try:
                    parsed_args = json.loads(args)
                except json.JSONDecodeError:
                    parsed_args = None
            command = ""
            workdir = ""
            if isinstance(parsed_args, dict):
                command = parsed_args.get("command", "")
                workdir = parsed_args.get("workdir", "")
            lines.append(f"- {prefix}[call] `{name}`")
            if workdir:
                lines.append(f"  - workdir: `{redact_text(workdir)}`")
            if command:
                lines.append("  - command:")
                lines.append("    ```")
                for line in redact_text(command).splitlines() or [""]:
                    lines.append(f"    {line}")
                lines.append("    ```")
            elif args:
                lines.append("  - arguments:")
                lines.append("    ```")
                for line in redact_text(extract_text(args)).splitlines() or [""]:
                    lines.append(f"    {line}")
                lines.append("    ```")
            continue

        if etype == "function_call_output":
            output = ev.get("output") or (msg.get("output") if isinstance(msg, dict) else None)
            if output:
                lines.append(f"- {prefix}[output]")
                lines.append("  ```")
                for line in redact_text(extract_text(output)).splitlines() or [""]:
                    lines.append(f"  {line}")
                lines.append("  ```")
            continue

        if etype in {"message", "agent_message"}:
            content = ev.get("message") or ev.get("content") or msg
            text = redact_text(extract_text(content))
            if text:
                lines.append(f"- {prefix}[message]")
                lines.extend(render_text_block(text))
            continue

        if etype == "agent_reasoning":
            text = ""
            if isinstance(msg, dict):
                text = msg.get("text") or ""
            else:
                text = extract_text(msg)
            text = redact_text(text)
            if text:
                lines.append(f"- {prefix}[reasoning]")
                lines.extend(render_text_block(text))
            continue

        if etype:
            text = redact_text(extract_text(msg))
            lines.append(f"- {prefix}[{etype}]")
            if text:
                lines.append("```")
                lines.append(text)
                lines.append("```")
            else:
                lines.append("```json")
                lines.append(dump_json(ev))
                lines.append("```")

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
