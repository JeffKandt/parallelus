#!/usr/bin/env python3
"""Generate a ready-to-send prompt for capturing a full context capsule."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from textwrap import dedent


DEFAULT_TOKEN_BUDGET = 1200
DEFAULT_REMINDER_PATH = Path("parallelus/manuals/capsules/remember-later.md")
TEMPLATE_PATH = Path("parallelus/manuals/templates/context_capsule_prompt.md")
DESIGN_DOC_PATH = Path("parallelus/manuals/prototypes/context-capsule.md")


def run_git_command(args: list[str]) -> str:
    try:
        completed = subprocess.run(
            ["git", *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return ""
    return completed.stdout.strip()


def current_branch() -> str:
    branch = run_git_command(["rev-parse", "--abbrev-ref", "HEAD"])
    return branch or "unknown"


def sanitise_branch(branch: str) -> Path:
    parts: list[str] = []
    for raw_part in branch.split("/"):
        part = raw_part.strip()
        if not part:
            continue
        safe = re.sub(r"[^A-Za-z0-9._-]+", "-", part)
        parts.append(safe)
    if not parts:
        return Path("unknown-branch")
    return Path(*parts)


def branch_slug(branch: str) -> str:
    slug = branch.replace("/", "-")
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", slug)
    return slug or "unknown-branch"


def read_optional_file(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    stripped = text.strip()
    return stripped if stripped else None


def build_capsule_path(branch: str, override: str | None, timestamp: datetime) -> Path:
    if override:
        return Path(override)
    capsule_root = Path("parallelus/manuals/capsules") / sanitise_branch(branch)
    filename = f"{timestamp.strftime('%Y%m%dT%H%M%SZ')}.md"
    return capsule_root / filename


def write_stub(
    path: Path,
    branch: str,
    plan_slug: str,
    session_marker: str | None,
    token_budget: int,
    version: str,
) -> bool:
    if path.exists():
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    created_at = datetime.now(timezone.utc).isoformat()
    front_matter = dedent(
        f"""---
        branch: {branch}
        source_session: {session_marker or '<fill-latest-session-marker>'}
        created_at: {created_at}
        primary_objective: <describe the immediate focus in one sentence>
        token_budget: {token_budget}
        version: {version}
        ---
        """
    ).strip()
    body = dedent(
        """
        # Mission Snapshot
        - **User intent:** <summarise the latest user request>
        - **Current status:** <branch state, outstanding checks>

        # Key Decisions & Rationale
        1. <Decision> — <Why it was made>

        # Active Workstreams
        - **<Workstream>** — scope, owner, blockers.

        # Pending Actions
        - [ ] <Action item> (owner, trigger)

        # Knowledge Base
        - <Reference> — <why it matters>

        # Risks & Watchpoints
        - <Risk> — <mitigation>

        # Transcript Highlights
        - <Timestamp or log reference> — <key takeaway>

        # Exploratory Threads & User Preferences
        - **<Topic>** — <current hypothesis or preference>; next step: <follow-up>.

        # Consistency Checklist
        - [ ] Capsule aligns with docs/plans/{plan_slug}.md latest entry.
        - [ ] Capsule aligns with docs/progress/{plan_slug}.md latest entry.
        - [ ] Referenced commits/PRs are included in current branch history.
        - [ ] Sensitive data removed.
        """
    ).strip()
    path.write_text(f"{front_matter}\n\n{body}\n", encoding="utf-8")
    return True


def build_prompt(
    *,
    branch: str,
    capsule_path: Path,
    plan_path: Path,
    progress_path: Path,
    reminder_path: Path,
    reminder_contents: str | None,
    template_path: Path,
    design_path: Path,
    session_marker: str | None,
    token_budget: int,
    capsule_version: str,
    timestamp: datetime,
) -> str:
    plan_line = f"- Branch plan: `{plan_path}`" if plan_path.exists() else "- Branch plan: (no file detected)"
    progress_line = (
        f"- Progress log: `{progress_path}`"
        if progress_path.exists()
        else "- Progress log: (no file detected)"
    )
    reminders_line = f"- Reminder inbox: `{reminder_path}`"
    session_line = session_marker or "<fill-latest-session-marker>"
    reminder_section = ""
    if reminder_contents:
        reminder_section = dedent(
            f"""
            Reminder inbox snapshot (trim once captured):
            ```markdown
            {reminder_contents}
            ```
            """
        ).strip()

    prompt_body = dedent(
        f"""
        You are the main agent for branch `{branch}`. Flush your current working memory into a
        complete context capsule so a successor session feels like the same collaborator.

        Requirements:
        - Write the capsule to `{capsule_path}` (create the file if it does not exist).
        - Follow the structure defined in `{template_path}`.
        - Include the metadata front matter with:
          - `branch: {branch}`
          - `source_session: {session_line}` (use the most recent session marker)
          - `created_at: {timestamp.astimezone(timezone.utc).isoformat()}`
          - `primary_objective`: one-sentence summary of the current focus
          - `token_budget: {token_budget}`
          - `version: {capsule_version}`

        Reference artifacts before writing:
        {plan_line}
        {progress_line}
        {reminders_line}
        - Latest committed diffs relevant to the objectives.
        - Any `/compact` or summary artifacts already produced this session.

        Scope of the capsule:
        - Capture mission snapshot, key decisions, active workstreams, pending actions, knowledge references, risks, transcript highlights, and exploratory threads exactly as outlined in the template.
        - Integrate every "remember this later" reminder that is still relevant; once incorporated, clear or annotate the reminder inbox entry so it is not duplicated next time.
        - Surface unresolved hypotheses or user preferences even if they have not been promoted to the plan notebook yet.
        - Prefer concise bullets that cite source artifacts (commit hashes, plan entries, timestamps) instead of verbose prose.

        Quality gate before returning the capsule:
        - Cross-check the plan and progress notebook for consistency.
        - Flag any mismatches or missing updates in the `Risks & Watchpoints` section.
        - Ensure there are no TODO placeholders remaining.
        - Confirm the final capsule fits within {token_budget} tokens (≈4.5k characters).

        Respond with only the completed Markdown capsule body ready to commit to `{capsule_path}`.
        If you need additional guidance on capsule expectations, review `{design_path}` first.
        """
    ).strip()

    if reminder_section:
        prompt_body = f"{prompt_body}\n\n{reminder_section}"

    return prompt_body + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a context capsule capture prompt")
    parser.add_argument(
        "--capsule-path",
        dest="capsule_path",
        help="Path (relative or absolute) where the capsule should be written",
    )
    parser.add_argument(
        "--session-marker",
        dest="session_marker",
        help="Latest session marker to pre-fill in the prompt",
    )
    parser.add_argument(
        "--plan-slug",
        dest="plan_slug",
        help="Slug used for plan/progress docs (defaults to branch name with '/' replaced by '-')",
    )
    parser.add_argument(
        "--token-budget",
        dest="token_budget",
        type=int,
        default=DEFAULT_TOKEN_BUDGET,
        help="Token budget reminder to embed in the prompt",
    )
    parser.add_argument(
        "--reminder-path",
        dest="reminder_path",
        default=str(DEFAULT_REMINDER_PATH),
        help="Path to the reminder inbox document",
    )
    parser.add_argument(
        "--include-reminders",
        dest="include_reminders",
        action="store_true",
        default=True,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--no-reminders",
        dest="include_reminders",
        action="store_false",
        help="Do not embed reminder inbox contents in the prompt",
    )
    parser.add_argument(
        "--write-stub",
        dest="write_stub",
        action="store_true",
        help="Create a capsule stub using the template if the file is missing",
    )
    parser.add_argument(
        "--version",
        dest="capsule_version",
        default="0.1",
        help="Capsule version string to include in the prompt",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    timestamp = datetime.now(timezone.utc)
    branch = current_branch()
    capsule_path = build_capsule_path(branch, args.capsule_path, timestamp)

    plan_slug = args.plan_slug or branch_slug(branch)
    plan_path = Path("docs/plans") / f"{plan_slug}.md"
    progress_path = Path("docs/progress") / f"{plan_slug}.md"
    reminder_path = Path(args.reminder_path)

    reminder_contents = None
    if args.include_reminders:
        reminder_contents = read_optional_file(reminder_path)

    if args.write_stub:
        stub_created = write_stub(
            capsule_path,
            branch,
            plan_slug,
            args.session_marker,
            args.token_budget,
            args.capsule_version,
        )
    else:
        stub_created = False

    prompt = build_prompt(
        branch=branch,
        capsule_path=capsule_path,
        plan_path=plan_path,
        progress_path=progress_path,
        reminder_path=reminder_path,
        reminder_contents=reminder_contents,
        template_path=TEMPLATE_PATH,
        design_path=DESIGN_DOC_PATH,
        session_marker=args.session_marker,
        token_budget=args.token_budget,
        capsule_version=args.capsule_version,
        timestamp=timestamp,
    )

    header_lines = [
        "# Capsule Capture Prompt",
        "Copy the block below into the active agent session to generate a capsule.",
        f"Target file: {capsule_path}",
    ]
    if args.session_marker:
        header_lines.append(f"Session marker: {args.session_marker}")
    if stub_created:
        header_lines.append("Capsule stub created.")
    header = "\n".join(header_lines)

    sys.stdout.write(f"{header}\n\n")
    sys.stdout.write(prompt)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
