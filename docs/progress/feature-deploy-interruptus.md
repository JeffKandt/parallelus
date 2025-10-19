# Branch Progress — feature/deploy-interruptus

## 2025-10-19 13:10:47 UTC
**Objectives**
- Redeploy the Parallelus workflow into the `interruptus` repository and capture verification steps.

**Work Performed**
- Reviewed `AGENTS.md` core guardrails and `docs/agents/deployment.md` before planning any deployment commands.
- Ran `make read_bootstrap`, inspected existing session logs, and confirmed no 2025-10-19 session existed prior to `make start_session`.
- Gathered the current state of `/Users/jeff/Code/interruptus` (branch `main`, dirty due to `dev-test/analysis` assets) to inform deployment parameters.
- Bootstrapped `feature/deploy-interruptus`, opened the branch plan/progress notebooks, and recorded session objectives + guardrail acknowledgements.
- Executed `.agents/bin/deploy_agents_process.sh --mode overlay --lang python --name interruptus --force /Users/jeff/Code/interruptus`, capturing the overlay notice and .bak backups for AGENTS, `.agents`, and `docs/agents` assets.
- Trimmed the legacy agent-integration block from `interruptus/Makefile` so the canonical snippet inserted by the deployment script no longer overrides `ROOT` or breaks `make read_bootstrap`.
- Verified the refreshed tooling by running `make read_bootstrap` inside interruptus; noted that full bootstrap drill remains pending until the large overlay diff is staged or cleaned.
- Updated `.agents/bin/deploy_agents_process.sh` to preserve existing `docs/agents/project/` content during overlay deployments and added an `--overlay-no-backup` flag for explicit upgrade runs.
- Refreshed `docs/agents/deployment.md` to document the new overlay behaviour and flag.
- Added `--overlay-upgrade` shorthand (clean-tree enforced, no backups, forces overlay mode) and validated help/arg parsing; captured follow-up to exercise it on a real repo.
- Reset interruptus to a clean state, ran `.agents/bin/deploy_agents_process.sh --overlay-upgrade /Users/jeff/Code/interruptus`, and confirmed the overlay completed without generating `.bak` files for docs/agents/project.
- Removed the redeployed Makefile's duplicate include block again and restored `PROJECT_NAME="interruptus"` plus adapter commands in `.agents/agentrc` so `make read_bootstrap` reports the correct project name with updated guardrail defaults.
- Re-ran `make read_bootstrap` post-upgrade to verify detection output and note remaining unmerged feature branches flagged by the guardrail.
- Patched the deployment script so backup-free overlays skip the `AGENTS.md` notice and updated the deployment guide to explain the conditional behaviour.
- Updated overlay logic to refresh only `docs/reviews/README.md` (leaving historical reviews untouched) and moved the senior architect review template into `docs/agents/templates/review_report_template.md` for reuse.
- Redeployed into interruptus again using `--overlay-upgrade` after the working tree was reset, confirming backups stayed disabled and project docs remained intact.

**Artifacts**
- docs/plans/feature-deploy-interruptus.md
- docs/progress/feature-deploy-interruptus.md
- /Users/jeff/Code/interruptus/Makefile (removed duplicate agent includes)

**Next Actions**
- Merge `.bak` backups in interruptus (AGENTS, `.agents/**`, `docs/agents/**`) with project-specific guidance, then remove the overlay notice once reconciled.
- Run the full post-deployment drill (`make bootstrap`, `make start_session`, `make turn_end`) in interruptus after staging or stashing the overlay diff.
- Capture outcomes + TODOs in interruptus notebooks once verification completes.
- Tidy the `.agents/hooks/*.bak` backups generated during deployment (or keep for recovery) and reconcile the overlay notice when local instructions are merged.
- Run the full post-deployment drill (`make bootstrap`, `make start_session`, `make turn_end`) in interruptus after staging or stashing the overlay diff.
- Capture outcomes + TODOs in interruptus notebooks once verification completes.
- Remove the inaccurate overlay notice from `/Users/jeff/Code/interruptus/AGENTS.md` now that backups were skipped, or regenerate it after deciding which instructions to keep.
- Ensure reviewers know the template lives under `docs/agents/templates/` (update docs/interruptus guidance after verification).
