# Branch Plan — feature/deploy-interruptus

## Objectives
- Redeploy the Parallelus agent process into the `interruptus` repository from the latest `parallelus` source.
- Ensure deployment artefacts (AGENTS.md, `.agents/`, docs) align with current guardrails and adapters.
- Capture verification steps and follow-up tasks so the interruptus team can resume guarded operations.

## Checklist
- [x] Review `AGENTS.md` guardrails for this session.
- [x] Re-read `docs/agents/deployment.md` to confirm deployment procedure.
- [x] Inspect `/Users/jeff/Code/interruptus` repo status and note outstanding changes.
- [x] Execute `.agents/bin/deploy_agents_process.sh` in overlay mode against the interruptus repo.
- [ ] Run the post-deployment verification drill (`make read_bootstrap` ➝ `make bootstrap` ➝ `make start_session` ➝ `make turn_end`) inside interruptus once the working tree is clean.
- [ ] Confirm deployment artefacts and update notebooks/progress with outcomes and TODOs.
- [x] Update `.agents/bin/deploy_agents_process.sh` to avoid overwriting `docs/agents/project/` content during overlay deployments.
- [x] Evaluate backup behaviour of the deployment script and document/implement a safe upgrade flag to reduce `.bak` churn.
- [x] Expose and validate the new `--overlay-upgrade` helper against a real repository before recommending it to operators.
- [x] Prevent the overlay notice from referencing backups when `--overlay-no-backup` / `--overlay-upgrade` suppresses `.bak` files.
- [x] Limit overlay refreshes in `docs/reviews/` to scaffold docs and relocate the review template into `docs/agents/templates/`.

## Next Actions
- Review the generated `.bak` backups in interruptus, merge any repository-specific guidance, and plan removal of the overlay notice in `AGENTS.md`.
- Finalise Makefile integration changes (legacy include block removed; confirm no additional adjustments needed).
- Run the post-deployment verification drill after the interruptus worktree is cleaned up or staged.
- Document results and any follow-ups in branch progress + interruptus project notes.
- Implement and verify the new overlay skip/backup behaviour before rerunning deployment.
- Update downstream documentation to point reviewers at the relocated template (PR-ready once verification completes).
