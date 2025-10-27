#!/usr/bin/env python3
"""
Generate a consolidated branch/PR report for make read_bootstrap output.
"""

from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional


@dataclass
class BranchInfo:
    name: str
    remote: bool = False
    local: bool = False
    pr_number: Optional[int] = None
    pr_title: Optional[str] = None
    pr_state: Optional[str] = None
    pr_created_at: Optional[str] = None

    @property
    def status(self) -> str:
        if self.remote and self.local:
            return "remote & local"
        if self.remote:
            return "remote-only"
        if self.local:
            return "local-only"
        return "unknown"

    @property
    def action(self) -> str:
        if self.pr_number and not self.local:
            return "fetch branch & review"
        if self.pr_number and self.local:
            return "review/merge locally"
        if not self.pr_number and self.remote and not self.local:
            return "fetch branch & decide"
        if not self.pr_number and self.local:
            return "decide: merge/archive/delete"
        return ""


def run(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def list_branches(ref: str) -> List[str]:
    result = run(["git", "branch", ref])
    if result.returncode != 0:
        return []
    names = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("*"):
            line = line[1:].strip()
        names.append(line)
    return names


def list_prs() -> List[Dict]:
    result = run(["gh", "pr", "list", "--json", "number,title,headRefName,state,createdAt"])
    if result.returncode != 0:
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    return data


def build_report() -> List[BranchInfo]:
    remote_branches = list_branches("-r")
    local_branches = list_branches("")
    prs = list_prs()

    branch_map: Dict[str, BranchInfo] = {}

    for rb in remote_branches:
        key = rb.replace("origin/", "", 1) if rb.startswith("origin/") else rb
        info = branch_map.setdefault(key, BranchInfo(name=key))
        info.remote = True

    for lb in local_branches:
        key = lb
        info = branch_map.setdefault(key, BranchInfo(name=key))
        info.local = True

    for pr in prs:
        head = pr.get("headRefName") or ""
        info = branch_map.setdefault(head, BranchInfo(name=head))
        info.pr_number = pr.get("number")
        info.pr_title = pr.get("title")
        info.pr_state = pr.get("state")
        info.pr_created_at = pr.get("createdAt")

    return sorted(branch_map.values(), key=lambda x: x.name)


def format_report(branches: List[BranchInfo]) -> str:
    lines = []
    header = f"{'Branch':40} {'Status':18} {'PR':45} {'Action'}"
    lines.append(header)
    lines.append("-" * len(header))
    for info in branches:
        pr_part = "-"
        if info.pr_number:
            pr_part = f"#{info.pr_number} – {info.pr_title} ({info.pr_state}, {info.pr_created_at})"
        lines.append(
            f"{info.name:40} {info.status:18} {pr_part:45} {info.action}"
        )
    return "\n".join(lines)


def main() -> None:
    report = build_report()
    print(format_report(report))
    print("\nTip: request a review with `Senior review request: <branch-name>`")


if __name__ == "__main__":
    main()
