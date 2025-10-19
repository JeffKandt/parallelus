# Senior Architect Review Scope — {{BRANCH_NAME}}

## Context
- **Branch:** {{BRANCH_NAME}}
- **Commit under review:** $(git rev-parse HEAD)
- **Remote check:** ensure the commit exists on origin/feature-publish-repo before review begins.
- **Focus:** Guardrail updates for tmux overlays, subagent orchestration, CI audit process, transcript capture commitments, and lint/test toolchain setup.

## Preconditions
- Working tree is clean and matches the pushed commit.
- CI (`make ci`) has passed on this commit.
- No additional changes will be introduced until the review is complete.

## Objectives
- [ ] Review code and docs between the base commit (origin/main) and the commit hash above.
- [ ] Validate guardrails introduced on this branch.
- [ ] Confirm CI/lint/test coverage and smoke tests for the changes.
- [ ] Inspect plan/progress updates for alignment with guardrail expectations.
- [ ] (Add branch-specific objectives here.)

## Key Artifacts
- Add the key artifacts for this branch: code files, docs, progress entries, CI results, etc.

## Review Deliverable
- Produce `docs/reviews/{{BRANCH_FILE_STEM}}-{{DATE}}.md` with:
  - `Reviewed-Branch`, `Reviewed-Commit`, `Reviewed-On`, `Decision`.
  - Severity-classified findings with evidence and remediation notes.
  - Summary and follow-up recommendations.

_Work read-only except for the review file described above._
