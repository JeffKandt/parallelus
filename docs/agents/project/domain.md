# Interruptus Domain Notes ## Interruption Taxonomy
- **Mechanical Interruption (MI)** – overlap/gap-grab events detected from raw diarization + ASR timing.
- **Semantic Interruption (SI)** – LLM-classified events once Semantic pipeline lands.
- **Supportive Overlap (SO)** – non-adversarial overlaps; still tracked for equity metrics. ## Diarization & Transcription
- Pyannote diarization is the default; see `docs/diarizer_tuning_workflow.md` and `docs/interactive_diarization_testing.md` for parameter sweeps.
- Whisper transcription merges with diarization turns prior to MI/SI/SO classification.
- Speaker roster resolution lives in `speakers.py`; prefer pure functions for ID → name mapping. ## Reporting & Metrics
- Export speaking-time percentages alongside event candidates (`events_candidates.jsonl`).
- Markdown/JSON reports (Deterministic pipeline deterministic) are generated before LLM embellishments.
- Future Semantic pipeline metrics include pertinence scoring, lost duration, and equity indices. ## Feed Sync & Workspace Layout
- Feed metadata lives in `feed.yaml`; helpers in `scripts/fetch_feed.py` and `interruptus.feed_sync` manage episode mirroring.
- Human-readable symlinks accompany hashed episode directories after feed sync to ease CLI discovery. ## Deployment Notes
- Remote automation flows target `m4-mac-mini`; ensure env parity (torch, torchaudio, numpy, huggingface-hub) between local and remote hosts.
- `make check-deps` validates remote PATH coverage. These domain notes complement the process docs so contributors understand the
underlying audio-analysis context while following the portable agent workflow.
