# issue-22 current-state survey (coding)

## Scope
Audit every WAKES-ON/wake mention in this repo's rulebook files (excluding
docs/issue-* trees, which are per-issue records, not rulebook text).

## Method
`grep -rni "wake" --include="*.md" --include="*.sh" .` over the whole tree,
excluding `.git`.

## Hits

### Rulebook file (in scope)
- `review/hooks/directive.sh:61-68` — the `review` role directive's closing
  section, "YOUR RECORD IS THE BOARD":
  > YOUR RECORD IS THE BOARD (do not skip this): WAKES-ON reads
  > docs/issue-<n>/reports/review.md ONLY — research files, surveys, and
  > proposals wake no one. The record is execution-surface material, so:
  > write it as your FIRST act of phase 2, and update its loop_state at
  > every transition. Ending phase 2 without your record committed on the
  > branch means the board never saw your work and no downstream role can
  > ever be woken by it. (Measured: a phase-1-only issue left the board
  > empty and machine wake-up dead.)

  This is the only rulebook file in the repo containing WAKES-ON/wake text.
  It mixes two things: (a) review's own record state/format — which file is
  review's record, when to write it, when to update loop_state — and (b) a
  restatement of the WAKES-ON routing mechanism's general behavior
  (consequences of not committing the record, "no downstream role... woken",
  "machine wake-up dead"). It does not name a specific role by name, so it
  does not literally trip "names which role a state summons," but it does
  restate routing mechanics and consequences that now live at canon
  (on-the-record docs/specs/wake-routing.md per the issue), duplicating
  content this rulebook should defer to the host doc for.

### Historical record (out of scope)
- `docs/proposals/2026-07-26-contract-v2-conformance.md` (multiple lines) —
  a past decision record for the v1→v2 contract migration (WAKES-ON
  replacing ACCEPTS). This is a standing-bucket historical proposal, not
  live rulebook text prescribing current behavior; issue-20 precedent
  treated similar historical prose as untouched. Left as-is.

### Not found
- No coding/qa/verify/core role directive files exist in this repo (this
  repo — review-agent-rulebook — carries only the `review` role's
  rulebook; other roles' directives live in other repos, e.g.
  tokenmaxxxer-core per the issue text). No README.md wake mentions.
  `docs/specs/` has no wake mentions.

## Write set (frozen for this issue)
- `review/hooks/directive.sh` (lines 61-68 region) — phase 2 only, not
  touched this session.

## Scout
Skipped — spec-shaped edit with no design decision open (the issue names
the exact file class, the exact rule, and the exact host doc to repoint
to); this is the scout-directive's literal-no-open-decision skip
condition.
