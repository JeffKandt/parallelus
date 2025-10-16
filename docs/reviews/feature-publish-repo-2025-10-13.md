Reviewed-Branch: feature/publish-repo
Reviewed-Commit: 6fdb91f7f97260492d73a4abbf53c0c368796322
Reviewed-On: 2025-10-16
Decision: changes requested

## Findings
- **Blocker:** Role prompt parsing now depends on PyYAML, but the runtime never installs it (`.agents/bin/subagent_manager.sh:282`, `requirements.txt:1`). Any launch that references a prompt with YAML front matter (e.g. the updated senior architect role) will raise `ModuleNotFoundError: No module named 'yaml'`, so the manager fails before opening the sandbox.
- **Blocker:** Role metadata export JSON-encodes scalar values before exporting them (`.agents/bin/subagent_manager.sh:333-340`). Strings like the configured Codex model become `\"gpt-5-codex\"`, so we end up invoking `codex --model "\"gpt-5-codex\""`, which passes the quotes to Codex and breaks model selection.

## Summary
The branch adds solid guardrail documentation, tmux awareness, and CI automation, but the new role front-matter plumbing currently bricks subagent launches by requiring an untracked dependency and mangling runtime overrides. Fix those blockers, re-run `make ci`, and I can take another look.

## Recommendations
1. Install PyYAML (either add it to `requirements.txt` or vendor a parser) before exercising the role front matter.
2. Export scalar overrides verbatim—reserve JSON encoding for lists/dicts that truly need it—so Codex receives the intended `--model`, sandbox, and approval values.
