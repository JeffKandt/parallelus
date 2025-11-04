#!/usr/bin/env python3
"""
Generate a consolidated branch/PR report for make read_bootstrap output.
"""

from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass
import os
from typing import Dict, List, Optional, Tuple


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


def detect_default_branch(remote: str) -> str:
    result = run(["git", "symbolic-ref", f"refs/remotes/{remote}/HEAD"])
    if result.returncode == 0:
        ref = result.stdout.strip()
        prefix = f"refs/remotes/{remote}/"
        if ref.startswith(prefix):
            return ref[len(prefix) :]
    return "main"


def verify_ref(ref: str) -> bool:
    return run(["git", "rev-parse", "--verify", ref]).returncode == 0


def resolve_base_ref(remote: str) -> Tuple[str, str]:
    default_branch = detect_default_branch(remote)
    candidates = [
        f"{remote}/{default_branch}",
        default_branch,
        "origin/main",
        "main",
    ]
    for candidate in candidates:
        if verify_ref(candidate):
            if "/" in candidate:
                branch = candidate.split("/", 1)[1]
            else:
                branch = candidate
            return candidate, branch
    return "main", "main"


def normalize_ref(ref: str, remote: str) -> Optional[str]:
    ref = ref.strip()
    if not ref:
        return None
    local_prefix = "refs/heads/"
    remote_prefix = f"refs/remotes/{remote}/"
    if ref.startswith(local_prefix):
        return ref[len(local_prefix) :]
    if ref.startswith(remote_prefix):
        suffix = ref[len(remote_prefix) :]
        if suffix == "HEAD":
            return None
        return suffix
    return None


def list_unmerged(prefix: str, base_ref: str, remote: str) -> List[str]:
    result = run(
        [
            "git",
            "for-each-ref",
            "--format=%(refname)",
            "--no-merged",
            base_ref,
            prefix,
        ]
    )
    if result.returncode != 0:
        return []
    names = []
    for line in result.stdout.splitlines():
        name = normalize_ref(line, remote)
        if not name:
            continue
        names.append(name)
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


def build_report() -> Tuple[List[BranchInfo], str]:
    remote_name = os.environ.get("BASE_REMOTE", "origin")
    base_ref, base_branch = resolve_base_ref(remote_name)
    remote_branches = list_unmerged(f"refs/remotes/{remote_name}", base_ref, remote_name)
    local_branches = list_unmerged("refs/heads", base_ref, remote_name)

    branches_to_include = set(remote_branches) | set(local_branches)
    filtered = {
        name
        for name in branches_to_include
        if name and name != base_branch and not name.startswith("archive/")
    }

    prs = list_prs()
    branch_map: Dict[str, BranchInfo] = {}

    for name in sorted(filtered):
        info = branch_map.setdefault(name, BranchInfo(name=name))
        if name in remote_branches:
            info.remote = True
        if name in local_branches:
            info.local = True

    for pr in prs:
        head = pr.get("headRefName") or ""
        if head not in filtered:
            continue
        info = branch_map.setdefault(head, BranchInfo(name=head))
        info.pr_number = pr.get("number")
        info.pr_title = pr.get("title")
        info.pr_state = pr.get("state")
        info.pr_created_at = pr.get("createdAt")

    return sorted(branch_map.values(), key=lambda x: x.name), base_branch


def format_report(branches: List[BranchInfo], base_branch: str) -> str:
    lines = []
    if not branches:
        lines.append(f"No branches with unmerged commits relative to {base_branch}.")
        return "\n".join(lines)

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
    lines.append("")
    lines.append("Tips:")
    lines.append(" - Request a quality review with `Senior review request: <branch-name>`")
    lines.append(" - Request an orientation with `Branch overview request: <branch-name>`")
    return "\n".join(lines)


def main() -> None:
    report, base_branch = build_report()
    print(format_report(report, base_branch))


if __name__ == "__main__":
    main()
