#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any, Optional


def _write_text(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


def _append_bytes(path: str, data: bytes) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "ab") as fh:
        fh.write(data)


def _summarize_event(evt: dict[str, Any]) -> Optional[str]:
    typ = str(evt.get("type") or "")
    if not typ:
        return None

    if typ == "thread.started":
        tid = evt.get("thread_id")
        return f"[exec] thread.started id={tid}"

    if typ == "turn.started":
        return "[exec] turn.started"

    if typ == "turn.completed":
        usage = evt.get("usage") or {}
        inp = usage.get("input_tokens")
        out = usage.get("output_tokens")
        cached = usage.get("cached_input_tokens")
        parts = []
        if inp is not None:
            parts.append(f"in={inp}")
        if cached is not None:
            parts.append(f"cached_in={cached}")
        if out is not None:
            parts.append(f"out={out}")
        suffix = (" " + " ".join(parts)) if parts else ""
        return f"[exec] turn.completed{suffix}"

    if typ == "item.completed":
        item = evt.get("item") or {}
        item_type = item.get("type")
        if item_type and item_type != "agent_message":
            return f"[exec] item.completed type={item_type}"
        return None

    if typ.endswith(".started") or typ.endswith(".completed") or typ.endswith(".failed"):
        return f"[exec] {typ}"

    return None


def _run_json(args: argparse.Namespace) -> int:
    session_id: Optional[str] = None
    last_agent_text: Optional[str] = None

    for raw in sys.stdin.buffer:
        if args.events_path:
            _append_bytes(args.events_path, raw)

        line = raw.decode("utf-8", "replace").strip()
        if not line:
            continue

        try:
            evt = json.loads(line)
        except Exception:
            # Preserve some visibility if parsing fails.
            if args.print_events:
                sys.stdout.write(f"[exec] <unparseable> {line}\n")
                sys.stdout.flush()
            continue

        typ = evt.get("type")
        if typ == "thread.started" and not session_id:
            tid = evt.get("thread_id")
            if isinstance(tid, str) and tid:
                session_id = tid
                if args.session_id_path:
                    _write_text(args.session_id_path, tid + "\n")

        if typ == "item.completed":
            item = evt.get("item") or {}
            if item.get("type") == "agent_message":
                text = item.get("text")
                if text is not None:
                    last_agent_text = str(text)
                    sys.stdout.write(last_agent_text.rstrip("\n") + "\n")
                    sys.stdout.flush()
                    if args.last_message_path:
                        _write_text(args.last_message_path, last_agent_text.rstrip("\n") + "\n")
                    continue

        if args.print_events:
            summary = _summarize_event(evt)
            if summary:
                sys.stdout.write(summary + "\n")
                sys.stdout.flush()

    return 0


def _run_text(args: argparse.Namespace) -> int:
    session_id: Optional[str] = None
    pattern = re.compile(r"\bsession id:\s*([0-9a-fA-F-]{36})\b")

    for line in sys.stdin:
        sys.stdout.write(line)
        sys.stdout.flush()
        if session_id is None:
            match = pattern.search(line)
            if match:
                session_id = match.group(1)
                if args.session_id_path:
                    try:
                        _write_text(args.session_id_path, session_id + "\n")
                    except Exception:
                        pass

    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["json", "text"], required=True)
    parser.add_argument("--events-path")
    parser.add_argument("--session-id-path")
    parser.add_argument("--last-message-path")
    parser.add_argument("--no-print-events", dest="print_events", action="store_false")
    parser.set_defaults(print_events=True)
    args = parser.parse_args()

    if args.mode == "json":
        return _run_json(args)
    return _run_text(args)


if __name__ == "__main__":
    raise SystemExit(main())

