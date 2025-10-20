# Git Workflow Manual

Parallelus supports two ways to land finished feature branches on the base
branch, plus an archival path for work that will not merge. Regardless of the
route, finish the guardrails first: notebooks up to date, retrospective audit
captured, senior architect review completed via the subagent, and CI passing.

## Repository Status & Unmerged Branch Triage
1. Run `make read_bootstrap` from the repo root. Capture the emitted `REPO_MODE`,
   `BASE_BRANCH`, and any `UNMERGED_REMOTE` / `UNMERGED_LOCAL` branches in your
   status recap.
2. Open the active branch plan and progress notebooks so you understand prior
   objectives and outstanding TODOs before deciding how to handle each branch.
3. For every unmerged branch, decide with the maintainer whether to merge,
   archive, defer, or prune. Do not take unilateral action; record the decision
   path in the progress notebook.

If the repo exposes `.agents/custom/` guidance, read it during Recon so your
triage choices respect project-specific rules.

## Option A – Direct Merge (`make merge`)
1. Confirm guardrails are satisfied (`make turn_end`, subagent review, CI).
2. Run `make merge slug=<slug>` to fast-forward the feature branch into the
   detected base branch.
3. The helper recounts senior review/retrospective artefacts, runs CI, and
   deletes the feature branch when complete.

## Option B – Pull Request on Remote (GitHub)
1. Finish guardrails locally exactly as above.
2. Push the feature branch (`git push origin feature/<slug>`).
3. Create the PR:
   - Using GitHub CLI: `gh pr create --fill` (or supply a template). Include
     links to the senior architect review file and the retrospective report.
   - Or use the GitHub web UI / API with the same information.
4. Ensure CI/required checks run on the PR. The senior review already lives in
   the branch; cite its file in the description for reviewers.
5. Once approvals and checks are green, merge the PR via GitHub (squash/merge as
   appropriate for the repo).
6. Update the local clone: `git checkout main && git pull`.
7. Delete the remote feature branch if desired (`gh pr merge --delete-branch`
   or GitHub UI).

Remember: guardrails are enforced before pushing. The PR route adds human review
and CI gates on the remote, but you must still run the local checklist first.

## Archival Flow (`make archive`)
Use archival when work will not merge (superseded, exploratory, deprecated).
1. Ensure the branch plan/progress notebooks clearly explain why the branch is
   being archived and that all useful findings are folded into canonical docs.
2. Run `make archive slug=<slug>`; the helper switches to `main`, fast-forwards,
   and moves the branch to `archive/<slug>` (locally and optionally on the
   remote).
3. Notify the maintainer of any follow-up tasks (bugs discovered, backlog items
   to resurrect later) and record the archival decision in the progress log.
4. Prune local worktrees or sandboxes associated with the branch.

Archived branches remain accessible via `git log archive/<slug>` but disappear
from the unmerged lists reported by `make read_bootstrap`.

## Remote Branch Discovery & Cleanup
When triaging remote branches or PRs:
- `git fetch origin --all` to ensure you have the latest state.
- List interesting branches: `git branch -r | grep -E '(feature|pull|codex|pr)'`.
- Inspect diffs quickly: `git show-branch origin/<branch>` or
  `git checkout -b pr-<id> origin/<branch>` for deeper review.

Document any cleanup actions (archival, merge, deletion) in the branch progress
log, and confirm the main branch returns to Recon & Planning mode once triage
finishes.
