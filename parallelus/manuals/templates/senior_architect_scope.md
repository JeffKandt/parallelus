# Senior Architect Review Scope

## Context
- Parent branch: {{PARENT_BRANCH}}
- Commit under review: {{TARGET_COMMIT}}
- Expected review output path: {{REVIEW_PATH}}
- Goal: provide an explicit architecture review for the requested scope
  (default: all feature-branch changes intended for merge to `main`).

## Preconditions
- Workspace context is pinned to branch `{{PARENT_BRANCH}}` at commit `{{TARGET_COMMIT}}`.
- Review is performed on committed state; no new implementation changes during this pass.
- Scope is explicit (full branch or bounded subset) and documented in the review.

## Objectives
- [ ] Review all relevant changes for the requested scope on `{{PARENT_BRANCH}}`.
- [ ] Evaluate required acceptance criteria/gates with explicit `yes/no` status and supporting evidence.
- [ ] Identify remaining risks, regressions, or missing validation.
- [ ] Confirm the review metadata targets `{{PARENT_BRANCH}}` + `{{TARGET_COMMIT}}`.
- [ ] If phase gates are defined in an execution-plan document, quote each in-scope gate verbatim and evaluate it individually.

## Acceptance Criteria
- Review file includes `Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`, `Decision`.
- Each required gate/criterion has: satisfaction status, evidence (paths + command outputs), and residual risks.
- Findings are severity-classified and include actionable remediation notes.
- Gate evaluation uses the exact in-scope acceptance-gate wording from the cited execution plan (when present).

## Notes
- Operate read-only except for writing the review markdown deliverable.
- Do not run bootstrap helpers or branch-changing workflows (`make bootstrap`, etc.).
- If the request is a partial or phased review, state the bounded scope explicitly and call out what remains out-of-scope.
- If branch or commit context drifts, restore it before continuing and call out the incident in the review notes.
