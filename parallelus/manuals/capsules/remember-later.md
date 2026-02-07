# Context Capsule Reminder Inbox

Use `make remember_later` to append structured reminders that should surface in
future context capsules. Each entry records the capture timestamp, optional
topic, the note itself, and any follow-up suggestions. Remove or annotate
entries once they have been folded into a capsule or formalised in the progress
notebook so this inbox reflects only outstanding context.

When you are ready to convert reminders into a full capsule, run
`make capsule_prompt stub=1` to generate a prompt and optional capsule skeleton.
The helper lists this inbox so the responding agent can fold the outstanding
notes into the `Exploratory Threads & User Preferences` section before clearing
them from this file.
