# Python Adapter

The Python adapter ensures every workflow runs inside the pinned virtualenv and
wraps lint/test/format tasks with consistent commands.

## Bootstrap Steps
1. `eval "$(make start_session)"` – enables logging and confirms repo mode.
2. `make bootstrap slug=<slug>` – creates/switches the feature branch.
3. `eval "$(make start_session)"` – records the prompt, session metadata, and logging.
4. `.agents/adapters/python/env.sh` – creates `.venv` (if missing) and installs
   `requirements.txt`.
5. Activate on demand: `source .venv/bin/activate` or rely on adapter scripts
   (they source the venv automatically).

## Adapter Scripts
- `env.sh` – creates/activates the venv and installs dependencies.
- `test.sh` – runs `${PY_TEST_CMD}` (`pytest -m "not slow" -q` by default).
- `lint.sh` – runs `${PY_LINT_CMD}` (`ruff check` + `black --check`).
- `format.sh` – runs `${PY_FORMAT_CMD}` (formatter helpers).

All scripts read configuration knobs from `.agents/agentrc`.

## Make Targets
Including `.agents/make/python.mk` adds:
- `make lint`
- `make format`
- `make test`
- `make ci` (runs `lint` then `test`)

## Usage Patterns
```bash
# Ensure environment is ready
.agents/adapters/python/env.sh

# Run lint + tests before committing
taskset -c 0 make ci  # optional pinning for reproducibility

# Format code proactively
make format
```

## Build & CLI Helpers
- CLI runs: `python -m interruptus.cli tests/fixtures/audio/parity_sample.wav \
    --out out/ --speaker-roster docs/examples/speakers.csv --use-stubs`
- Quick tests: `pytest -m "not slow"`
- Full test suite: `pytest`
- Lint check: `ruff check src tests`
- Formatting check: `black --check src tests`

Always run these commands inside the activated venv (the adapter scripts do this
for you).
