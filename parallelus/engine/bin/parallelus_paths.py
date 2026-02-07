"""Shared session-path resolution helpers for Python scripts."""

from __future__ import annotations

import os
from pathlib import Path


def normalize_repo_path(repo_root: Path, value: str) -> Path:
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = repo_root / path
    return path.resolve()


def load_agentrc(repo_root: Path) -> dict[str, str]:
    path = repo_root / "parallelus/engine" / "agentrc"
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]
        values[key] = val
    return values


def sessions_write_root(repo_root: Path) -> Path:
    override = os.environ.get("PARALLELUS_SESSIONS_WRITE_DIR", "").strip()
    if override:
        return normalize_repo_path(repo_root, override)
    return (repo_root / ".parallelus" / "sessions").resolve()


def sessions_legacy_root(repo_root: Path) -> Path:
    return (repo_root / "sessions").resolve()


def sessions_read_roots(repo_root: Path, configured_root: str | None = None) -> list[Path]:
    configured = configured_root
    if configured is None:
        configured = load_agentrc(repo_root).get("SESSION_DIR")

    candidates: list[Path] = [sessions_write_root(repo_root)]
    if configured:
        candidates.append(normalize_repo_path(repo_root, configured))
    candidates.append(sessions_legacy_root(repo_root))

    roots: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        roots.append(candidate)
    return roots


def resolve_session_dir(repo_root: Path, session_id: str, configured_root: str | None = None) -> Path:
    for root in sessions_read_roots(repo_root, configured_root=configured_root):
        candidate = root / session_id
        if candidate.is_dir():
            return candidate
    return sessions_write_root(repo_root) / session_id
