---
name: severity-classification
description: Use while acting as the review role in the draft-reported state, optionally, when the review's scope has been explicitly extended into risk-weighting a finding — not for ordinary fidelity-checking. Use to attach a severity band to a finding already recorded by finding-record; never to decide whether a finding exists.
---

# severity-classification

Belongs to `draft-reported`. Optional — used only where the review's
scope is explicitly extended into risk-weighting; severity is not
required for pure fidelity-checking, per the existing spec's scoping of
this role to a per-requirement verdict rather than a holistic quality
judgment. Only run this skill when the user (or the engagement scope
agreed at `idle -> scoped`) has said severity is in scope.

## What it asks the user for

Nothing to compute the band itself — severity, like the verdict, is the
reviewer's own judgment call, made solo (interaction research, "What
proceeds without asking": "the compliance-audit source shows severity
being *re-negotiated after the fact* when management pushes back... implying
the initial assignment was the auditor's alone"). It asks the user only if
a severity band is disputed after the fact, in which case it may retain
the finding but adjust the recorded band — mirroring the compliance-audit
convention that a disputed finding is not dropped, only re-rated
(`docs/reports/research/2026-07-27-role-interaction/review.md`, "Moments
that call for a human", item 6, and "When the answer is ambiguous", item
1).

## The shape of the classification

A **deterministic table-lookup**, not an averaged subjective score. The
practice research is explicit that this is the field's own converged
lesson: DREAD's damage/reproducibility/exploitability/affected-users/
discoverability average was *abandoned by Microsoft itself*, its own
originating organization, for being too subjective and inconsistently
scored across reviewers, in favor of the SDL "bug bar" — a fixed lookup
table over enumerable, objectively-observable characteristics of the
finding (`docs/reports/research/2026-07-27-role-practice/review.md`,
"Artifacts and their shapes" and "Decision criteria and gates"). This
skill therefore uses one of two sourced deterministic band shapes, chosen
by the engagement:

- **Chromium's five bands** — Critical (S0) / High (S1) / Medium (S2) /
  Low (S3) / Unknown (S4), each defined by a concrete capability
  (arbitrary code/resource access at full privilege = Critical;
  cross-origin data read or code exec in another origin's context = High;
  limited info read/modify, or harmless-alone-but-combinable = Medium;
  higher-severity-in-theory but with extreme mitigating/limited-scope
  factors = Low).
- **Microsoft's four-level bug bar** — Critical / Important / Moderate /
  Low, looked up from characteristics of the finding (attacker
  authentication state: anonymous vs. authenticated; scope: default vs.
  special-configuration scenario; persistence: temporary vs. permanent),
  not computed from a weighted average.

Do not use DREAD's averaged-score shape for this skill, per the sourced
disagreement above.

## The artifact

Writes a `severity` field onto the finding's existing block in
`review-record.md` (the same block `finding-record` wrote), not a
separate file — this is an addition to an existing finding, not a new
artifact. Field:

- **`severity`** — one of the chosen band's values (e.g. `Critical`,
  `High`, `Medium`, `Low`, and, for Chromium's five-band scheme,
  `Unknown`).

This field is read, not gated: `state-gate.sh`'s transition check does not
require `severity` to be present on any block, since it is optional by
design.

## What this skill never does

- Compute severity as an average of subjective factors (the DREAD shape).
- Decide whether a finding exists — that is `finding-record`'s job, prior
  to this skill running.
- Fix, patch, or propose remediation for the finding it classifies.
- Run when severity is out of the engagement's agreed scope.
