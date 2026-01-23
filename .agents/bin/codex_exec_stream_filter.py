#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from typing import Any, Optional


def _write_text(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


def _append_bytes(path: str, data: bytes) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "ab") as fh:
        fh.write(data)


_SHELL_WRAPPER_RE = re.compile(r"^\s*(?:/bin/)?(?:ba)?sh\s+-lc\s+(.+)\s*$")
_ZSH_WRAPPER_RE = re.compile(r"^\s*(?:/bin/)?zsh\s+-lc\s+(.+)\s*$")


def _truthy_env(name: str) -> bool:
    raw = (os.getenv(name) or "").strip().lower()
    return raw not in {"", "0", "false", "no", "off"}


def _redact(text: str) -> str:
    # Best-effort redaction; this is not a secrets scanner.
    key_value = re.compile(r"(?i)\b(api[_-]?key|access[_-]?key|secret|token|password)\b\s*=\s*([^\s'\"\\]+)")
    auth_bearer = re.compile(r"(?i)\b(authorization)\s*:\s*(bearer)\s+([^\s]+)")
    cli_flag = re.compile(r"(?i)\b(--(?:api[-_]key|token|password|secret))\s+([^\s]+)")

    redacted = text
    redacted = key_value.sub(lambda m: f"{m.group(1)}=REDACTED", redacted)
    redacted = auth_bearer.sub(lambda m: f"{m.group(1)}: {m.group(2)} REDACTED", redacted)
    redacted = cli_flag.sub(lambda m: f"{m.group(1)} REDACTED", redacted)
    return redacted


def _unwrap_shell_command(command: str) -> str:
    cmd = command.strip()
    for rx in (_SHELL_WRAPPER_RE, _ZSH_WRAPPER_RE):
        m = rx.match(cmd)
        if not m:
            continue
        inner = m.group(1).strip()
        if inner.startswith("'") and inner.endswith("'"):
            inner = inner[1:-1]
        if inner.startswith('"') and inner.endswith('"'):
            inner = inner[1:-1]
        return inner.strip()
    return cmd


def _truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[: max(0, limit - 3)] + "..."


def _format_output_snippet(output: str, *, max_lines: int, max_chars: int) -> list[str]:
    out = (output or "").rstrip("\n")
    if not out:
        return []

    # Avoid splitting potentially large output into every line; we only need
    # the last few non-empty lines.
    tail: list[str] = []
    remaining = out
    while remaining and len(tail) < max_lines:
        before, sep, last = remaining.rpartition("\n")
        remaining = before if sep else ""
        if last.strip():
            tail.append(last)
    if not tail:
        return []

    rendered: list[str] = []
    for line in reversed(tail):
        line = _truncate(_redact(line.rstrip()), max_chars)
        rendered.append(line)
    return rendered


@dataclass
class _InflightItem:
    item_type: str
    command: Optional[str] = None


def _summarize_event_compact(evt: dict[str, Any]) -> Optional[str]:
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


def _summarize_event_tui(evt: dict[str, Any], inflight: dict[str, _InflightItem]) -> Optional[str]:
    typ = str(evt.get("type") or "")
    if not typ:
        return None

    verbose = _truthy_env("SUBAGENT_EXEC_SUMMARY_VERBOSE")
    output_lines = int(os.getenv("SUBAGENT_EXEC_OUTPUT_LINES") or "4")

    if typ == "thread.started":
        tid = evt.get("thread_id")
        return f"- Started exec session ({tid})"

    if typ == "turn.started":
        return "- Starting turn"

    if typ == "item.started":
        item = evt.get("item") or {}
        item_id = str(item.get("id") or "")
        item_type = str(item.get("type") or "")
        if item_id and item_type:
            inflight[item_id] = _InflightItem(item_type=item_type, command=item.get("command"))
        if item_type == "reasoning":
            return "- Thinking…"
        if item_type == "command_execution":
            cmd = _unwrap_shell_command(str(item.get("command") or ""))
            cmd = _truncate(_redact(cmd), 140)
            return f"- Run {cmd}"
        if verbose and item_type:
            return f"- Starting {item_type}"
        return None

    if typ == "item.failed":
        item = evt.get("item") or {}
        item_type = str(item.get("type") or "") or "item"
        error = item.get("error") or evt.get("error") or evt.get("message") or ""
        error_text = _truncate(_redact(str(error).strip()), 200) if error else ""
        if item_type == "command_execution":
            cmd = _unwrap_shell_command(str(item.get("command") or ""))
            cmd = _truncate(_redact(cmd), 140)
            if error_text:
                return f"- Command failed: {cmd}\n  └ {error_text}"
            return f"- Command failed: {cmd}"
        if error_text:
            return f"- Failed {item_type}\n  └ {error_text}"
        return f"- Failed {item_type}"

    if typ == "item.completed":
        item = evt.get("item") or {}
        item_id = str(item.get("id") or "")
        item_type = str(item.get("type") or "")
        if item_id and item_id in inflight:
            prior = inflight.pop(item_id)
            item_type = item_type or prior.item_type
        if item_type == "agent_message":
            return None
        if item_type == "reasoning":
            return None
        if item_type == "command_execution":
            cmd = _unwrap_shell_command(str(item.get("command") or ""))
            cmd = _truncate(_redact(cmd), 140)
            exit_code = item.get("exit_code")
            prefix = "- Ran"
            suffix = f" (exit {exit_code})" if exit_code is not None else ""
            out = str(item.get("aggregated_output") or "")
            snippet = _format_output_snippet(out, max_lines=output_lines if verbose else 1, max_chars=180)
            if not snippet:
                return f"{prefix} {cmd}{suffix}"
            body = "\n".join(f"  └ {line}" for line in snippet)
            return f"{prefix} {cmd}{suffix}\n{body}"
        # Generic tool-ish item
        if verbose:
            return f"- Completed {item_type}"
        return None

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
        suffix = (" (" + ", ".join(parts) + ")") if parts else ""
        return f"- Turn complete{suffix}"

    if typ.endswith(".failed"):
        return f"- {typ}"

    return None


def _run_json(args: argparse.Namespace) -> int:
    session_id: Optional[str] = None
    last_agent_text: Optional[str] = None
    inflight: dict[str, _InflightItem] = {}

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
            if args.style == "tui":
                summary = _summarize_event_tui(evt, inflight)
            else:
                summary = _summarize_event_compact(evt)
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
    parser.add_argument("--style", choices=["compact", "tui"], default="tui")
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
