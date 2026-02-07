# Senior Architect Review Scope

## Context
- Parent branch: {{PARENT_BRANCH}}
- Commit under review: {{TARGET_COMMIT}}
- Expected review output path: {{REVIEW_PATH}}
- Goal: provide an explicit gate evaluation for the current phase scope only.

## Preconditions
- Workspace context is pinned to branch `{{PARENT_BRANCH}}` at commit `{{TARGET_COMMIT}}`.
- Review is performed on committed state; no new implementation changes during this pass.
- Focus remains within the requested phase scope and acceptance gates.

## Objectives
- [ ] Review all relevant changes for the requested phase on `{{PARENT_BRANCH}}`.
- [ ] Evaluate each phase exit gate with explicit `yes/no` status and supporting evidence.
- [ ] Identify remaining risks, regressions, or missing validation.
- [ ] Confirm the review metadata targets `{{PARENT_BRANCH}}` + `{{TARGET_COMMIT}}`.

## Acceptance Criteria
- Review file includes `Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`, `Decision`.
- Each required gate has: satisfaction status, evidence (paths + command outputs), and residual risks.
- Findings are severity-classified and include actionable remediation notes.

## Notes
- Operate read-only except for writing the review markdown deliverable.
- Do not run bootstrap helpers or branch-changing workflows (`make bootstrap`, etc.).
- If branch or commit context drifts, restore it before continuing and call out the incident in the review notes.
