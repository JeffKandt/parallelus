#!/usr/bin/env python3
"""
Convert a Codex subagent session JSONL log into a Markdown transcript.

Usage:
    parallelus/engine/bin/subagent_session_to_transcript.py path/to/session.jsonl [--output transcript.md]

If --output is omitted, the script writes alongside the source file using the
same basename with `-transcript.md`.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Iterable, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session_path", type=Path, help="Path to subagent.session.jsonl")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional output path (defaults to <session>.md)",
    )
    return parser.parse_args()


def format_timestamp(raw: str | None) -> str:
    if not raw:
        return "Unknown time"
    try:
        # Allow both Z and offset forms.
        if raw.endswith("Z"):
            dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        else:
            dt = datetime.fromisoformat(raw)
        return dt.strftime("%Y-%m-%d %H:%M:%S UTC")
    except ValueError:
        return raw


def flatten_content(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") in {"output_text", "input_text"}:
                    parts.append(item.get("text") or item.get("input_text") or "")
                elif "Text" in item:
                    parts.append(item["Text"].get("text", ""))
                else:
                    parts.append(flatten_content(list(item.values())))
            else:
                parts.append(str(item))
        return "\n".join(filter(None, parts))
    if isinstance(content, dict):
        return flatten_content(list(content.values()))
    return str(content)


def extract_command(msg: dict) -> str:
    parsed = msg.get("parsed_cmd")
    if isinstance(parsed, list) and parsed:
        parts = []
        for item in parsed:
            if isinstance(item, dict):
                if "cmd" in item:
                    parts.append(item["cmd"])
                elif "arg" in item:
                    parts.append(item["arg"])
        if parts:
            return " ".join(parts)
    command = msg.get("command")
    if isinstance(command, list):
        return " ".join(command)
    return str(command or "")


def iter_entries(session_path: Path) -> Iterable[Tuple[str, str, str]]:
    with session_path.open("r", encoding="utf-8") as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw:
                continue
            data = json.loads(raw)
            payload = data.get("payload", {})
            msg = payload.get("msg", {})
            ts = data.get("ts") or payload.get("ts")
            ts_fmt = format_timestamp(ts)
            msg_type = msg.get("type")

            if msg_type == "agent_message":
                text = flatten_content(msg.get("message", "")).strip()
                if text:
                    yield ts_fmt, "Subagent", text
            elif msg_type == "user_message":
                text = flatten_content(msg.get("message", "")).strip()
                if text:
                    yield ts_fmt, "Main agent", text
            elif msg_type == "message":
                role = msg.get("role", "message").capitalize()
                text = flatten_content(msg.get("content", "")).strip()
                if text:
                    yield ts_fmt, role, text
            elif msg_type == "exec_command_begin":
                cmd = extract_command(msg).strip()
                if cmd:
                    yield ts_fmt, "Command", cmd
            elif msg_type == "exec_command_end":
                exit_code = msg.get("exit_code")
                stdout = (msg.get("stdout") or "").strip()
                stderr = (msg.get("stderr") or "").strip()
                parts = []
                if exit_code is not None:
                    parts.append(f"exit {exit_code}")
                if stdout:
                    parts.append("stdout:\n" + stdout)
                if stderr:
                    parts.append("stderr:\n" + stderr)
                text = "\n".join(parts).strip()
                if text:
                    yield ts_fmt, "Command result", text
            elif msg_type == "agent_summary":
                text = flatten_content(msg.get("summary", "")).strip()
                if text:
                    yield ts_fmt, "Subagent summary", text


def write_transcript(output_path: Path, entries: Iterable[Tuple[str, str, str]]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as out:
        out.write("# Subagent Session Transcript\n\n")
        for ts, role, text in entries:
            text_block = text.replace("\n", "\n  ")
            out.write(f"- **{ts}** — {role}: {text_block}\n")


def main() -> int:
    args = parse_args()
    session_path: Path = args.session_path
    if not session_path.exists():
        print(f"session file not found: {session_path}", file=sys.stderr)
        return 1
    default_output = session_path.with_name(f"{session_path.stem}-transcript.md")
    output_path: Path = args.output if args.output else default_output
    entries = list(iter_entries(session_path))
    write_transcript(output_path, entries)
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
