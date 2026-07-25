---
name: finding-record
description: Use while acting as the review role in the auditing or draft-reported state, to record one verdict per specification requirement in review-record.md. Use whenever a requirement has been checked and needs a verdict written down — never to fix or patch what was found.
---

# finding-record

Belongs to `auditing` (initial recording) and `draft-reported` (dispute
resolution recorded inline, still against the same finding). Produces the
per-requirement finding record inside `review-record.md`, the role's state
file, at the requirement blocks below the header block.

This skill never writes to any file other than `review-record.md`. It does
not fix, patch, or suggest a patch for anything it finds — it reports.

## What it asks the user for

Nothing, by default — recording a verdict is the reviewer's own
professional judgment call, made solo, per the interaction research's
finding that severity assignment and "is this a finding at all" both
proceed without asking (`docs/reports/research/2026-07-27-role-interaction/review.md`,
"What proceeds without asking"). The skill asks the user only when it
cannot check a requirement at all from what it has: "the spec requires X
be logged at runtime; I can't observe that from a static diff — can you
point me at a log sample, or should this be `Unverifiable`?" That answer,
or the absence of one, decides the verdict; it does not gate the write.

In `draft-reported`, if the reviewed party disputes a finding, this skill
asks the user to state their side, records it, and re-examines the
evidence — it does not treat the dispute itself as a request to fix
anything.

## The verdict set

Exactly one of, per requirement:

- **`Present`** — implemented as specified.
- **`Surface`** — something exists at the requirement's name or shape, but
  does not actually do what it requires.
- **`Absent`** — nothing addresses the requirement.
- **`Incorrect`** — addressed, but wrong.
- **`Unverifiable`** — the reviewer genuinely cannot check this requirement
  from the evidence and access it has been given; distinct from `Absent`
  (verifiably not there). Added because two independent research passes
  converge on the same gap: Fagan inspection's follow-up phase and AICPA's
  tolerable-deviation framing (practice research), and reviewers'
  repeated, real need to request evidence or access they don't yet have
  before a requirement can be checked at all (interaction research,
  "Moments that call for a human", item 3).

Never merge these into a bare pass/fail.

## The artifact and its field list

Written to `review-record.md`, in this repository's root (path
configurable via `REVIEW_RECORD_NAME`), as one `---`-delimited block per
requirement below the header block. Field list, taken from the practice
research's synthesis of the OWASP finding template, CVSS/bug-bar
precedent, and Fagan inspection's reader-narrates-the-artifact discipline
(`docs/reports/research/2026-07-27-role-practice/review.md`, "What must a
finding record contain to be actionable?"):

1. **`requirement`** — a stable identifier for the specific
   requirement/claim being checked, verbatim from the specification (or a
   stable id if the spec numbers its own requirements).
2. **`verdict`** — one of the five values above.
3. **`evidence`** — a pointer into the actual diff: file path, line
   number, or hunk. Never a paraphrase of what the diff does — the
   reproduction path itself, mirroring OWASP's mandatory Evidence/PoC
   field and Fagan inspection's rule that the artifact is narrated, not
   summarized from memory. This is what makes the finding actionable: a
   claim of `Incorrect` or `Absent` with no evidence pointer is refused by
   this skill before it is written (see below).
4. **`rationale`** — one line connecting the evidence to the verdict:
   why this evidence supports this verdict, not a restatement of either.
5. **`spec_vs_built`** — required only when `verdict: Incorrect`: what the
   spec required, versus what was actually built. Optional/omitted for
   every other verdict.

Template at
`review-cycle/skills/finding-record/templates/finding-record-template.md`
is the field skeleton this skill fills in per requirement.

## Refusal the skill itself enforces

This skill refuses to accept a verdict of `Present`, `Surface`, `Absent`,
or `Incorrect` with no `evidence` pointer — mirroring OWASP's mandatory
Evidence/PoC field. `Unverifiable` is the one verdict that may carry an
`evidence` field describing what access/evidence was missing instead of a
diff pointer, since by definition there is no diff evidence to point at.

## What this skill never does

- Fix, patch, or propose a patch for anything it records, even if the
  user asks it to while giving an answer — if asked to fix what it found,
  say plainly that this role reports and does not fix, and that the
  finding stands recorded as-is pending the user's own decision on it.
- Merge the five verdicts into pass/fail.
- Write to any file other than `review-record.md`.
- Treat a complete-looking diff as a `Present` verdict without an evidence
  pointer into it.
