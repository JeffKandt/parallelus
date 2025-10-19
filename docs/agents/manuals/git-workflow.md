# Git Workflow Manual

Parallelus supports two ways to land finished feature branches on the base
branch. The guardrails require the same preparation either way: finish the work,
run the retrospective audit, capture the senior architect review (via the
subagent), and ensure branch notebooks are folded.

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
