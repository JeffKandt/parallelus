#!/usr/bin/env python3
"""Append a structured "remember this later" note for context capsules."""

from __future__ import annotations

import argparse
import datetime as _dt
import pathlib
import sys
from typing import List


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture a reminder that future context capsules should surface."
    )
    parser.add_argument(
        "--message",
        "-m",
        required=True,
        help="The reminder text to record.",
    )
    parser.add_argument(
        "--topic",
        help="Optional short topic label to group related reminders.",
    )
    parser.add_argument(
        "--next-step",
        dest="next_step",
        help="Optional next experiment or follow-up to suggest to successors.",
    )
    parser.add_argument(
        "--tag",
        dest="tags",
        action="append",
        default=[],
        help="Add one or more free-form tags (repeat flag for multiple).",
    )
    parser.add_argument(
        "--capsule-file",
        default="docs/agents/capsules/remember-later.md",
        help="Where to append the reminder (default: %(default)s).",
    )
    return parser


def format_entry(
    *, timestamp: str, message: str, topic: str | None, next_step: str | None, tags: List[str]
) -> str:
    lines = [f"## {timestamp}"]
    if topic:
        lines.append(f"- **Topic:** {topic.strip()}")
    lines.append(f"- **Note:** {message.strip()}")
    if next_step:
        lines.append(f"- **Next step:** {next_step.strip()}")
    if tags:
        tag_list = ", ".join(tag.strip() for tag in tags if tag.strip())
        if tag_list:
            lines.append(f"- **Tags:** {tag_list}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    reminder_path = pathlib.Path(args.capsule_file)
    reminder_path.parent.mkdir(parents=True, exist_ok=True)

    timestamp = _dt.datetime.now(_dt.UTC).strftime("%Y-%m-%d %H:%M:%S UTC")
    entry = format_entry(
        timestamp=timestamp,
        message=args.message,
        topic=args.topic,
        next_step=args.next_step,
        tags=args.tags,
    )

    needs_leading_newline = reminder_path.exists() and reminder_path.read_text(encoding="utf-8").strip() != ""
    with reminder_path.open("a", encoding="utf-8") as handle:
        if needs_leading_newline:
            handle.write("\n")
        handle.write(entry)

    print(f"Appended reminder to {reminder_path} ({timestamp}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
