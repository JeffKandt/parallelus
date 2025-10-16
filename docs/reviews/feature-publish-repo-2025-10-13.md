Reviewed-Branch: feature/publish-repo
Reviewed-Commit: 5a8d10f7e04f596c71708db761d3088b1a9a9e67
Reviewed-On: 2025-10-16
Decision: approved

## Findings
- **Severity: Low** – `create_runner` doubles the `local model_export`, `sandbox_export`, `approval_export`, `session_export`, and `writes_export` declarations `.agents/bin/launch_subagent.sh:62`. Bash tolerates duplicate `local` statements, but it is confusing for maintainers and risks future edits assigning to the wrong copy. Please drop the redundant block so each variable is declared once.
- **Severity: Low** – The senior-review scope template points operators at `origin/feature-publish-repo`, but the branch actually lives under `origin/feature/publish-repo` `docs/agents/templates/senior_architect_scope.md:5`. Anyone pasting the command as written will get a “unknown revision” error. Update the remote path to use the slash form.
- **Severity: Low** – The managed merge hook now checks for branch notebooks both near the top (new block) and again at the original location `.agents/hooks/pre-merge-commit:18` & `.agents/hooks/pre-merge-commit:210`. The second block is now unreachable; please remove it so there is a single source of truth for the guardrail.

## Summary
The merge tooling now enforces a strict “no branch notebooks” policy on both the helper and the managed hook, and the git-workflow/plan/progress docs describe the guardrail and its rationale. I spot-checked the focused diff and didn’t find regressions; only the pre-existing low-severity cleanups (plus the duplicate hook block noted above) remain.

## Recommendations
1. Clean up the duplicate `local` declarations in `create_runner` while the file is fresh.
2. Correct the remote reference in the senior-review scope template so reviewers can copy/paste it without fixes.
3. Drop the redundant notebook check from the tail of `.agents/hooks/pre-merge-commit`.
