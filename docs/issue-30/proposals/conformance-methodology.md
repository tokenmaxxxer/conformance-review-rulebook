---
subject: issue-30
role: review
loop_state: scope-proposed
---

# Proposal: conformance-review methodology and deliverable norms (issue #30)

## Request (paraphrased intent)

Fix, by domain research rather than intuition, what methodology and what
required components phase-1 proposals and phase-2 deliverables in this
rulebook must follow. See
`docs/issue-30/reports/conformance-review/scout-brief.md` for the survey
this proposal is built on, and
`docs/issue-30/reports/conformance-review/current-state-survey.md` for
what this role's plugin already implements.

## Constraints

- Phase-1 only — no file outside `docs/issue-30/**` is touched in this
  PR. Phase 2 (any change to `review/hooks/directive.sh`,
  `review/skills/**`, or the record template) executes only after
  Approve, per contract v3 s19.
- warrant-hunter / core canon: referenced by name and by the landed core
  commit only (this repo's own commit 892df80 already removed the
  vendored `stub-check.sh` copy) — no copy is created here.
- Existing record discipline is not weakened: the five-value verdict
  vocabulary, the mandatory evidence pointer, and the
  `code_under_review:`/`closed_checks` sha discipline in
  `closed-checks-gate.sh` all stay exactly as they are. This proposal's
  additions are net-additive (traceability explicitness, a `spec_ref`
  field, an explicit independence clause) — never a relaxation.

## (a) Proposal-norm (phase-1 document requirements)

Every phase-1 proposal in this rulebook (this one included) must:

1. Open with a **Request** section paraphrasing the triggering intent,
   not quoting the issue verbatim.
2. Name its **Constraints**, explicitly separating what this PR touches
   (phase 1: `docs/issue-<n>/**` only) from what phase 2 will touch.
3. Ground every adopted methodology choice in a **named external source**
   (a standard, a landed spec, or this repo's own prior
   `docs/reports/research/**`) — an unsourced preference is not
   sufficient basis for a rulebook rule. Where a claim is not backed by a
   source actually consulted this session, it must be marked
   `[known reference, not fetched live]` or `[assumption]`, per the
   scout-brief's own disclosure.
4. Separate **adopt** from **skip**, with a one-line reason each — a
   proposal that only lists what was adopted, with no record of what was
   considered and rejected, cannot be checked for having actually
   surveyed alternatives.
5. Close with **"How this will be judged"** — a checklist of externally
   verifiable conditions (file exists, gate exits 0, field present),
   never a subjective "looks right."

Rationale: this is the same shape `docs/issue-31/proposals/
implementation.md` already used successfully in this repo (see
current-state-survey) — reusing a proven in-repo shape rather than
inventing a new one is itself an instance of the "adopt over invent"
principle this proposal recommends for methodology choices generally.

## (b) Deliverable-norm (phase-2 review-record.md requirements)

**Adopted methodology: requirement-by-requirement traceability with a
mandatory evidence pointer, under an ISO 19011/IIA-style
evidence-based-and-independent audit discipline.** Concretely:

- The record is organized as one block per **discrete, spec-derived
  requirement** (already the `finding-record` shape) — never a single
  holistic verdict on "the artifact."
- Each block carries a closed verdict from the five-value vocabulary
  already in force: `Present | Surface | Absent | Incorrect |
  Unverifiable`.
- Each block's `evidence` field is a **pointer into the artifact**
  (file:line/hunk, or a named missing-access description for
  `Unverifiable`) — never a paraphrase or a bare assertion. This is
  already enforced (`finding-record`'s stated refusal), and stays exactly
  as strict.
- **New, additive field**: `spec_ref` — the exact clause/section/
  requirement-id in the spec being checked against, distinct from the
  free-text `requirement` field already in the template. Where the spec
  is unnumbered prose, `spec_ref` may be a stable locator (heading +
  paragraph) instead of a formal id, but must not be omitted — a
  traceability matrix needs a stable key on both sides (spec side and
  evidence side), and `requirement` alone (free text, potentially
  paraphrased) does not reliably serve as that key across re-review.
- Severity, where in scope, stays a **deterministic table lookup**
  (Chromium 5-band or Microsoft bug-bar shape), never an averaged
  subjective score (DREAD) — already decided in `severity-
  classification`, reaffirmed here as the ISO 19011/IIA-aligned choice
  (see rationale below).
- The reviewer's **independence from builder intent** stays absolute:
  working from "the artifact and the spec," never the building agent's
  stated intent — already the role's `USE_WHEN` clause, reaffirmed here
  as tracking ISO 19011's independence principle and IIA's Standard 1100,
  not an arbitrary house rule.

## (c) Rationale — why this methodology is not a preference but a fit

The role's stated purpose is: render a per-requirement verdict on whether
a built artifact matches its spec, from evidence, without deferring to
the builder's account of their own intent. Three converging bodies of
external practice independently arrive at the same shape for exactly
this purpose, which is the strongest kind of justification available
(convergent adoption, not a single source's idiosyncrasy):

- **Conformance testing practice** (ISO/IEC conformance assessment
  vocabulary; W3C and IETF conformance/interoperability report
  convention) decomposes a spec into discrete testable requirements and
  renders pass/fail/not-applicable per requirement, because a
  specification is itself a set of discrete normative statements — a
  single holistic verdict cannot be traced back to which statement it
  answers, and therefore cannot be disputed, re-checked, or partially
  remediated. This is a structural necessity, not a stylistic choice:
  any reviewer that collapses multiple requirements into one verdict has
  discarded exactly the information a downstream consumer needs to act.
- **Audit standards** (ISO 19011's evidence-based-approach and
  independence principles; IIA Standard 2310 Identifying Information,
  Standard 1100 Independence and Objectivity) require every finding to
  rest on verifiable evidence and to be produced by a party structurally
  separated from the work being audited. This maps directly onto why
  `finding-record` refuses a verdict with no evidence pointer, and why
  the role works "without the building agent's intent": an
  auditor/reviewer whose conclusions could be swapped for the auditee's
  own narrative is not independently verifying anything — it is
  transcribing. Adopting this is not optional if the role's stated value
  (a verdict that can be trusted *because* it is independent) is to hold.
- **Severity practice's own converged lesson** (DREAD abandoned by its
  originating org in favor of Microsoft's table-lookup bug bar; Chromium
  independently converged on the same deterministic-table shape) shows
  that when a field tries subjective averaged scoring for exactly this
  kind of judgment, it is abandoned in favor of enumerable, objective
  table lookups — because averaged subjective scores don't reproduce
  across reviewers, which defeats the same independence/verifiability
  goal above. This is why `spec_ref` and the evidence pointer are kept
  mandatory and machine-checkable rather than left to reviewer narrative.

In short: every methodology element adopted here is adopted because
relaxing it would specifically undermine the one thing this role exists
to provide — a verdict a third party can independently retrace to the
spec clause and the exact evidence, without having to trust either the
reviewer's memory or the builder's account.

## (d) Plugin reflection plan (phase 2 — not executed in this PR)

**`review/hooks/directive.sh`** — extend the existing `PRODUCES` value
(currently: `"extracted requirement list (or sampling derivation),
per-requirement verdicts with diff-pointer evidence, code_under_review:,
closed_checks cites keyed to that sha"`) to name the new field
explicitly:

```
PRODUCES="PRODUCES (required record fields): extracted requirement list (or sampling derivation), per-requirement verdicts with spec_ref + diff-pointer evidence, code_under_review:, closed_checks cites keyed to that sha"
```

No other directive value changes — `YOU_DECIDE`, `USE_WHEN`, and
`HAND_OFF` already state the verdict vocabulary and independence
constraint correctly; only `PRODUCES` needs the new required field named.

**`review/skills/finding-record/`** — add `spec_ref` to the field list in
`SKILL.md` (between `requirement` and `verdict`, since it's the
traceability key the requirement text alone doesn't reliably serve as)
and to `templates/finding-record-template.md`'s field skeleton. Update
the skill's stated refusal list to also refuse a write missing
`spec_ref` on any verdict other than `Unverifiable` (mirroring the
existing `evidence` refusal).

**Record/gate reflection** — no new gate file is proposed; the existing
core-canon `record-fields-gate.sh` (§20 minimum-content check,
registered core-side per issue #31) is the natural enforcement point once
`spec_ref` becomes a required field name, but wiring a field-name check
into that core-side gate is out of this repo's write set (core owns that
file) — phase 2 should file this as a follow-up against core if
field-level enforcement (not just section-presence) is wanted, rather
than vendoring a duplicate check locally, consistent with this issue's
own constraint against re-vendoring core canon.

**PR/gate condition to add** — phase 2's own `docs/issue-30/reports/
review.md` (the phase-2 record for this issue) must state, verbatim,
that `finding-record`'s template and `SKILL.md` were updated together
(not just one), since a template/doc drift here would silently produce
records missing `spec_ref` while the skill doc claims it's required.

## What is deliberately out of scope

- Formal ISO/IEC certification-body machinery (accredited labs,
  certification marks) — this role produces a review record, not a
  conformance certificate; adopting that machinery would be scope
  creep beyond what any consumer of this role's output needs.
- Full statistical audit sampling math (AICPA confidence-level/
  deviation-rate formulas) — noted in the scout brief as a real
  practice, not adopted; the existing "sampling derivation" note in
  `PRODUCES` is judged sufficient at this role's scale.
- Any change to `review/hooks/closed-checks-gate.sh` — unrelated to this
  issue's methodology question.
- Live web verification of every source cited — this session ran without
  confirmed web-search access; sources marked `[known reference, not
  fetched live]` in the scout brief should be re-verified before being
  cited externally, but are treated as sufficiently reliable common
  knowledge for this internal rulebook decision.

## How this will be judged

- `docs/issue-30/reports/conformance-review/scout-brief.md` and
  `current-state-survey.md` exist and each source claim is either linked
  or explicitly marked `[known reference]`/`[assumption]`.
- This proposal names, for every adopted methodology element, the
  specific external source or landed in-repo research it comes from, and
  separately lists at least one considered-and-skipped alternative.
- No file outside `docs/issue-30/**` is modified by this PR.
- Phase 2, once approved, updates `review/hooks/directive.sh`'s
  `PRODUCES` string and both `finding-record/SKILL.md` and its template
  together, adding `spec_ref` without removing or weakening any existing
  required field or refusal rule.
