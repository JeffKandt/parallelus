#!/usr/bin/env python3
import re
import sys
from pathlib import Path


PATTERNS = [
    (re.compile(r"-----BEGIN [A-Z ]+PRIVATE KEY-----[\s\S]+?-----END [A-Z ]+PRIVATE KEY-----"), "private key block"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "aws access key id"),
    (re.compile(r"\bASIA[0-9A-Z]{16}\b"), "aws session key id"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"), "github token"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9-]+\b"), "slack token"),
    (re.compile(r"\bsk-[A-Za-z0-9]{20,}\b"), "api key"),
    (re.compile(r"(?i)(bearer\s+)[A-Za-z0-9\-._~+/]+=*"), "bearer token"),
    (re.compile(r"(?i)\b(token|api[-_]?key|secret|password|passwd|pwd)\b\s*[:=]\s*[^\\s'\\\"]+"), "credential assignment"),
]


def redact_snippet(text: str, pattern: re.Pattern) -> str:
    return pattern.sub("[REDACTED]", text)


def scan_file(path: Path) -> list:
    findings = []
    try:
        content = path.read_text(encoding="utf-8", errors="ignore")
    except FileNotFoundError:
        return findings
    for pattern, label in PATTERNS:
        for match in pattern.finditer(content):
            start = max(match.start() - 40, 0)
            end = min(match.end() + 40, len(content))
            snippet = content[start:end].replace("\n", "\\n")
            snippet = redact_snippet(snippet, pattern)
            findings.append((label, snippet))
    return findings


def main() -> int:
    repo = Path(__file__).resolve().parents[2]
    reviews_dir = repo / "docs" / "reviews"
    if not reviews_dir.exists():
        return 0

    failures = []
    for path in sorted(reviews_dir.glob("*.md")):
        findings = scan_file(path)
        for label, snippet in findings:
            failures.append((path, label, snippet))

    if not failures:
        return 0

    print("review_secret_scan: potential secrets detected in review files:", file=sys.stderr)
    for path, label, snippet in failures:
        print(f"- {path.relative_to(repo)} ({label}) :: {snippet}", file=sys.stderr)
    print("review_secret_scan: redact or remove sensitive strings before merging.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
