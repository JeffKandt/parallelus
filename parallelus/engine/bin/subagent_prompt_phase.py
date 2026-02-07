#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path


def _env_phase():
    return os.environ.get("CODEX_PHASE") or os.environ.get("CODex_PHASE")


def current_phase():
    branch = (
        subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        .decode()
        .strip()
    )
    phase = _env_phase()
    if branch == "main":
        phase = phase or "Recon & Planning"
    else:
        phase = phase or "Active Execution"
    return branch, phase


def abbreviate_phase(name: str) -> str:
    if not name:
        return "-"
    lowered = name.lower()
    if "recon" in lowered:
        return "Recon"
    if "active" in lowered:
        return "Active"
    if "transition" in lowered:
        return "Transition"
    if "turn" in lowered and "end" in lowered:
        return "Turn-End"
    return name.split()[0]


def worktree_indicator() -> str:
    try:
        toplevel = (
            subprocess.check_output(["git", "rev-parse", "--show-toplevel"])
            .decode()
            .strip()
        )
    except subprocess.CalledProcessError:
        return "-"
    git_path = Path(toplevel) / ".git"
    indicator = "•"
    if git_path.is_file():
        try:
            content = git_path.read_text().strip()
        except OSError:
            return "WT"
        if content.startswith("gitdir:"):
            gitdir = content.split(":", 1)[1].strip()
            parts = Path(gitdir).parts
            slug = ""
            if "worktrees" in parts:
                idx = parts.index("worktrees")
                if idx + 1 < len(parts):
                    slug = parts[idx + 1]
            indicator = f"WT:{slug}" if slug else "WT"
        else:
            indicator = "WT"
    return indicator


if __name__ == "__main__":
    import argparse
    import json
    import time

    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", action="store_true")
    parser.add_argument("--heartbeat", action="store_true")
    parser.add_argument("--git-status", action="store_true")
    parser.add_argument("--worktree", action="store_true")
    parser.add_argument("--full-phase", action="store_true")
    args = parser.parse_args()
    branch, phase = current_phase()
    if args.branch:
        print(branch)
    elif args.heartbeat:
        registry = Path("parallelus/manuals/subagent-registry.json")
        value = "-"
        if registry.exists():
            try:
                data = json.loads(registry.read_text())
                running = [row for row in data if row.get("status") == "running"]
                if running:
                    ages = []
                    now = time.time()
                    for row in running:
                        log = row.get("log_path")
                        if log and os.path.exists(log):
                            mtime = os.path.getmtime(log)
                            delta = max(int(now - mtime), 0)
                            ages.append(delta)
                    if ages:
                        worst = max(ages)
                        minutes, seconds = divmod(worst, 60)
                        value = f"{minutes:02d}:{seconds:02d}"
                else:
                    value = "ready"
            except Exception:
                value = "err"
        print(value)
    elif args.git_status:
        try:
            out = subprocess.check_output(
                ["git", "status", "--porcelain"], stderr=subprocess.DEVNULL
            )
            lines = [ln for ln in out.decode().splitlines() if ln.strip()]
            print(f"Δ{len(lines)}" if lines else "✓")
        except Exception:
            print("-")
    elif args.worktree:
        print(worktree_indicator())
    else:
        if args.full_phase:
            print(phase)
        else:
            print(abbreviate_phase(phase))
