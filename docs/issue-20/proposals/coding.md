# Issue #20 — Proposal

Files: [README.md]

## Request (paraphrased)

Rename the one remaining stale "muster" prose mention in README.md to
"on-the-record", following the orchestration stack rename
(`tokenmaxxxer/muster` -> `tokenmaxxxer/on-the-record`).

## Constraints

- Historical docs (decision records, past reports) must stay untouched, even
  if they mention "muster" in a historical sense. (Survey found none under
  `docs/`, but the constraint still governs scope.)

## What will be done

- One-line rename at `README.md:56`:
  - Before: `muster installs it per role alongside the core marketplace. Kill switch:`
  - After: `on-the-record installs it per role alongside the core marketplace. Kill switch:`

## Out of scope

- Any other "muster" references that may exist in historical docs — none were
  found, but none will be touched if found later.

## How you'll know it worked

- `grep -n "muster" README.md` returns no matches.
- `README.md:56` reads naturally in context with "on-the-record" substituted
  for "muster".
