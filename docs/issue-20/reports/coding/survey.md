# Issue #20 — Current-State Survey

## Issue

"Sweep stale 'muster' mention after rename to on-the-record". The orchestration
stack was renamed (`tokenmaxxxer/muster` -> `tokenmaxxxer/on-the-record`,
plugin `orchestrate` -> `on-the-record`; see tokenmaxxxer/on-the-record#83).
One prose mention remains.

## Findings

- `README.md:56` currently reads:

  > muster installs it per role alongside the core marketplace. Kill switch:

  This is the stale prose mention the issue asks to rename to `on-the-record`.

- Repo-wide grep for `muster` (case-sensitive) turns up exactly one hit:

  ```
  README.md:56:muster installs it per role alongside the core marketplace. Kill switch:
  ```

- `grep -rln "muster" docs/` returns no matches — there is no historical
  docs/ content (decisions, reports) referencing "muster" in this repo, so
  there is nothing to carve out as "leave untouched" beyond the general
  principle. If any historical mentions are found later, they are explicitly
  out of scope per the issue body ("Historical docs untouched.").

## Scope confirmation

- In scope: the single live prose mention at `README.md:56`.
- Out of scope: any historical/decision-record mention of "muster" (none
  currently found under `docs/`, but the constraint holds regardless).

## Conclusion

The fix is a one-line rename in `README.md:56`, from `muster` to
`on-the-record`, with no other files requiring changes.
