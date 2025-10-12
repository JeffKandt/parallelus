# Self-Improvement Retrospective Logs

Turn-end retrospectives are recorded here as JSON Lines (`YYYY-MM-DD.jsonl`).
Each entry captures detected process issues with the following schema:

```
{
  "timestamp": "2025-10-12T07:58:00Z",
  "branch": "feature/process-review-gate",
  "session": "20251012-XXXX",
  "issues": [
    {
      "id": "lint-tool-missing",
      "root_cause": "make ci failed because ruff is not installed in the active environment",
      "mitigation": "Install ruff via pip in the project virtualenv",
      "prevention": "Add an environment check that fails early when ruff is absent",
      "evidence": "command -v ruff exited with status 1"
    }
  ]
}
```

Prevention actions are mirrored into the active branch plan as TODO items so the
main agent can track follow-up work. Empty `issues` arrays are acceptable when
no problems were detected.
