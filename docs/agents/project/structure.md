# Interruptus Repository Structure

## 1. Runtime Layout
- `src/interruptus/ingest.py` – CLI entry and input validation.
- `src/interruptus/transcription/` – Whisper wrappers.
- `src/interruptus/diarization/` – Pyannote shims and RTTM export.
- `src/interruptus/analysis/` – MI/SI/SO classification and metric aggregation.
- `src/interruptus/speakers.py` – roster-based identity resolution.
- `src/interruptus/llm/` – interruption prompts and semantic helpers.
- `src/interruptus/reporting/` – JSON/Markdown exports.
- `src/interruptus/pipeline.py` – orchestrates the full flow.
- `src/interruptus/core/` – reusable helpers.

Mirror this layout under `tests/`. Place audio fixtures in
`tests/fixtures/audio/`, golden outputs under `tests/fixtures/expectations/`, and
sample rosters under `docs/examples/`.

## 2. Build & CLI Commands
- Create venv: `python -m venv .venv`
- Activate: `source .venv/bin/activate`
- Install deps: `pip install -r requirements.txt`
- Run CLI stub: `python -m interruptus.cli tests/fixtures/audio/parity_sample.wav \
    --out out/ --speaker-roster docs/examples/speakers.csv --use-stubs`

## 3. Coding Style
- Follow PEP 8 (4-space indentation, `snake_case` functions, `PascalCase` classes).
- Use `@dataclass` or Pydantic models for transcript turns, interruption events,
  and metrics once validation is required.
- Store timing thresholds in `config.py` (`TimingThresholds`), not scattered
  magic numbers.
- Prefix helper names by category (`mi_`, `si_`, `so_`).
- Keep docstrings succinct and purpose-driven.

## 4. Testing Guidelines
- Tests live in `tests/` with filenames `test_*.py`.
- Target ≥80% coverage on `pipeline`, `analysis`, and `reporting`.
- Use parametrised tests to sweep thresholds (`overlap_ms_min`, `gap_ms_max`,
  `sustain_ms_min`).
- Gate Whisper/Pyannote smoke tests behind `@pytest.mark.slow`.
- Interactive diarization experiments: follow
  `docs/interactive_diarization_testing.md` (facilitate parameter tweaks via
  `scripts/run_diarization_test.py`).

## 5. Commit & PR Expectations
- Subject format: `Implement MI gap-grab detection` (imperative, ≤60 chars).
- Include PRD references, trade-offs, follow-up work in the body.
- List test commands executed (`pytest`, `ruff`, `black --check`).
- Attach updated artifact snippets when outputs change.
- Wait for CI (`CI` workflow) to pass and request review before merging.

## 6. Security & Configuration
- Keep `OPENAI_API_KEY`, `PYANNOTE_AUTH_TOKEN`, etc., in an untracked `.env`.
- ffmpeg must be installed system-wide (Homebrew on macOS).
- Never commit client audio; store only vetted development fixtures.
- Development test audio in `dev-test/ground-truth/` is acceptable when clearly
  labeled.

## 7. Planning & Progress Docs
- `docs/PLAN.md` – canonical roadmap (maintainers update post-merge).
- `docs/plans/<branch>.md` – branch-specific objectives.
- `docs/progress/<branch>.md` – branch log; pair updates with plan changes.
- Use `scripts/stitch_progress_logs.py` to merge branch logs back into
  `docs/PROGRESS.md` at feature completion.
