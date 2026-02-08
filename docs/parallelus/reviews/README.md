# Senior Architect Reviews

Store final, approved senior-architect review reports here using the filename
pattern `feature-my-branch-YYYYMMDD.md` (include additional suffixes if you run
multiple reviews in a day). Each report must include:

- `Reviewed-Branch: feature/<slug>` — matches the feature branch under review.
- `Reviewed-Commit: <hash>` — the exact commit SHA reviewed (must match the
  branch head at merge time).
- `Reviewed-On: YYYY-MM-DD` (UTC or include timezone).
- `Decision: approved` once blocking issues are resolved.
- A findings section where each item declares `Severity: <level>`.

The merge guardrails require that no finding in the approved report has
`Severity: High` or `Severity: Blocker`, and that you acknowledge any remaining
`Severity: Medium/Low/Info` items (see `AGENTS_MERGE_ACK_REVIEW`). Keep earlier
draft reviews on the feature branch if needed, but ensure the final approved
copy lives in this directory so it becomes a permanent artifact on the base
branch after merging. When a branch slug is reused in the future, create a new
dated review file instead of overwriting the earlier record.

Use `parallelus/manuals/templates/review_report_template.md` as the starting point for new reviews to ensure all required metadata and findings are recorded.
