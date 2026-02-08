"""Shared docs-path resolution helpers for Python scripts."""

from __future__ import annotations

from pathlib import Path
from typing import Iterator


def _unique_paths(paths: list[Path]) -> list[Path]:
    result: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        key = str(path)
        if key in seen:
            continue
        seen.add(key)
        result.append(path)
    return result


def branch_notebooks_root(repo_root: Path) -> Path:
    return repo_root / "docs" / "branches"


def branch_plan_write_path(repo_root: Path, slugged_branch: str) -> Path:
    return branch_notebooks_root(repo_root) / slugged_branch / "PLAN.md"


def branch_progress_write_path(repo_root: Path, slugged_branch: str) -> Path:
    return branch_notebooks_root(repo_root) / slugged_branch / "PROGRESS.md"


def branch_plan_read_path(repo_root: Path, slugged_branch: str) -> Path:
    return branch_plan_write_path(repo_root, slugged_branch)


def branch_progress_read_path(repo_root: Path, slugged_branch: str) -> Path:
    return branch_progress_write_path(repo_root, slugged_branch)


def iter_branch_progress_paths(repo_root: Path) -> Iterator[Path]:
    for path in sorted(branch_notebooks_root(repo_root).glob("*/PROGRESS.md")):
        yield path


def docs_parallelus_root(repo_root: Path) -> Path:
    return repo_root / "docs" / "parallelus"


def reviews_write_dir(repo_root: Path) -> Path:
    return docs_parallelus_root(repo_root) / "reviews"


def reviews_read_dirs(repo_root: Path) -> list[Path]:
    return _unique_paths([reviews_write_dir(repo_root)])


def self_improvement_write_root(repo_root: Path) -> Path:
    return docs_parallelus_root(repo_root) / "self-improvement"


def self_improvement_read_roots(repo_root: Path) -> list[Path]:
    return _unique_paths([self_improvement_write_root(repo_root)])


def marker_write_path(repo_root: Path, slugged_branch: str) -> Path:
    return self_improvement_write_root(repo_root) / "markers" / f"{slugged_branch}.json"


def marker_read_path(repo_root: Path, slugged_branch: str) -> Path:
    return marker_write_path(repo_root, slugged_branch)


def reports_write_dir(repo_root: Path) -> Path:
    return self_improvement_write_root(repo_root) / "reports"


def failures_write_dir(repo_root: Path) -> Path:
    return self_improvement_write_root(repo_root) / "failures"
