---
subject: issue-30
role: review
loop_state: scoped
---

# Current-state survey (issue #30)

## Repo/role identity

This repo's plugin is named `review` (`review/.claude-plugin/plugin.json`),
not literally "conformance-review" — the issue's domain framing
("conformance-review": checking an artifact against a spec/rulebook) is
what this role already does. No file or directory in the repo is named
`conformance-review`; issue #30's own output paths
(`docs/issue-30/reports/conformance-review/`,
`docs/issue-30/proposals/`) are new under `docs/issue-30/` only.

## Plugin structure

```
review/hooks/directive.sh           SessionStart stub, sources core canon
review/hooks/closed-checks-gate.sh  role-specific PreToolUse gate
review/hooks/hooks.json             SessionStart + one PreToolUse entry
review/skills/finding-record/       verdict schema + template
review/skills/severity-classification/  optional severity band lookup
```

`directive.sh` sources `core/hooks/lib/role-directive.sh`'s
`core_role_directive(you_decide, use_when, produces, hand_off)` and
supplies review's four values (see full text below). No local
`trailer-gate.sh` / `record-fields-gate.sh` / `handbook-trigger-gate.sh` /
`parse-check.sh` exist under `review/hooks/` — confirmed by
`docs/issue-31/reports/implementation/survey.md` and by
`docs/handbooks/review-hooks.md` (current-state handbook), consistent
with core canon promotion having already landed (commit a80bbfb, issue
#31).

Current directive text (`review/hooks/directive.sh`):

- `YOU_DECIDE`: "whether what was built matches what was specified — a
  per-requirement verdict (Present|Surface|Absent|Incorrect|
  Unverifiable), never a holistic code-quality judgment, never a fix"
- `USE_WHEN`: "after a build reaches a reviewable state, working from the
  artifact and the spec, deliberately without the building agent's
  intent"
- `PRODUCES`: "extracted requirement list (or sampling derivation),
  per-requirement verdicts with diff-pointer evidence,
  code_under_review:, closed_checks cites keyed to that sha"
- `HAND_OFF`: "findings addressed_to the owning role; never fixed here"

## Record structure (already defined, pre-dating issue #30)

`finding-record` skill (`review/skills/finding-record/SKILL.md`) already
specifies the per-requirement block written to `review-record.md`:
`requirement`, `verdict` (one of
Present/Surface/Absent/Incorrect/Unverifiable), `evidence` (diff pointer,
mandatory except describing what's missing for Unverifiable),
`rationale`, `spec_vs_built` (Incorrect only). `severity-classification`
adds an optional `severity` field using a deterministic table lookup
(Chromium 5-band or Microsoft 4-level bug bar), explicitly rejecting
DREAD's averaged-subjective-score shape.

This means issue #30's phase 2 target (a review-record.md deliverable
norm) is **largely already implemented** — issue #30's actual gap, per
its own text, is that the *methodology justification* for this shape was
not previously written down as an explicit proposal citing external
domain practice; it was derived from `docs/reports/research/2026-07-27-
role-practice/review.md` and `.../role-interaction/review.md` but never
packaged as a "why this and not something else" proposal document with
adopt/skip framing. That is what
`docs/issue-30/proposals/conformance-methodology.md` supplies.

## Core canon reference pattern (from issue #31/#34)

`git show a80bbfb` (issue #31 delivery) confirms: `directive.sh` is a
stub sourcing `${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/role-directive.sh`;
the three role-agnostic gates (trailer/record-fields/handbook-trigger)
were deleted from this repo and are registered core-side; `stub-check.sh`
is *not* vendored locally (`git show 892df80`, issue #34 delivery
removed a duplicate vendored copy, keeping the "run by reference against
the installed core plugin" convention). The pattern for issue #30 to
follow: reference core canon (and, per this issue's own constraint,
warrant-hunter/core issue #63) by name/link only — do not vendor a copy
into this repo.

## Sibling role-plugin proposal precedent

`docs/issue-31/proposals/implementation.md` and
`docs/issue-31/reports/implementation/survey.md` are the clearest
same-repo phase-1 precedent: YAML front-matter (`subject`, `role`,
`loop_state`), a "Request (paraphrased intent)" section, a "Constraints"
section naming the phase-1/phase-2 boundary explicitly, a "What will be
done (phase 2 only — not applied yet)" section broken into numbered
items each with its own rationale, an explicit "out of scope" section,
and a "How this will be judged" section with checkable criteria. The
conformance-methodology proposal below follows this same shape.

## approvers.md

`docs/specs/approvers.md` lists one GitHub login (`JiwonJung94`) who may
submit the PR Approve (or, single-account mode, the issue comment
"APPROVE issue-<n>/<role>") that opens phase 2, per contract v3 s19. Not
actioned in this session — phase 2 does not start until that approval
lands on the PR this session opens.
