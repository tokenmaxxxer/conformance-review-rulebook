---
subject: issue-39
role: review
loop_state: scope-proposed
---

# Proposal: mechanize the adopted conformance methodology (issue #39)

## Request (paraphrased intent)

Issue #30 adopted (by named external source, phase 1) and reflected
(phase 2, one prose word: `spec_ref`) a conformance methodology for this
role. That reflection lives only as a directive sentence and skill
prose — nothing mechanically checks a written record actually followed
it. Issue #39 asks to close that gap to `implementation-rulebook`'s
hook-machine bar: directive deepening (staged, facet-explicit, no
one-line summaries), a `PreToolUse` methodology gate that mechanically
checks the approved `PRODUCES` elements are present, order enforcement
via state tracking if the methodology has a sequence, gate tests, and
an agent/checklist if the methodology needs a repeated procedure. See
`docs/issue-39/reports/conformance-review/current-state-survey.md` for
what exists today and `scout-brief.md` for why field-scouting was
skipped (the field question is already answered by issue #30; this
issue is an internal-engineering mechanization of that answer).

## Constraints

- **Phase-1 only.** This PR touches only `docs/issue-39/**`. No file
  under `review/`, `tests/`, or `install.sh` is created, deleted, or
  edited in this PR. Everything below section (d) is a frozen plan for
  phase 2, executed only after a human approver's Approve, per contract
  v3 s19.
- **No APPROVE in this PR.** This proposal does not, and cannot, approve
  itself; phase 2 opens only through the two paths contract v3 s19
  names.
- **Canon reference only, never copy** (core canon-scripts.md,
  reaffirmed by issue #31 and #34 in this repo — `stub-check.sh` is run
  by reference against the installed `core` plugin, never vendored).
  Nothing proposed here vendors a byte copy of any canon script. The
  `pricing`/`performance-engineering` `methodology-gate.sh` files and
  `implementation-rulebook`'s `coding/hooks/{state,hunt-state,
  hunt-guard,coding-progress-gate}.sh` are **not** canon (they are
  sibling rulebooks' own role-specific code, not core-registered
  scripts) — reading them for engineering pattern and writing this
  role's own script from scratch, with review's own field names and
  write surfaces, is not a canon-copy question at all. No text from
  those files is reused verbatim anywhere below.
- **Role boundary / write_scope unchanged.** This role still only ever
  writes `docs/issue-<n>/reports/review.md` (phase 2) and its own
  phase-1 homes; the gate below only ever inspects writes to those same
  surfaces, never another role's.
- **Net-additive, never a relaxation.** Every check proposed below adds
  a mechanical floor under a requirement issue #30 already adopted in
  prose (five-value vocabulary, `spec_ref`, evidence pointer,
  `code_under_review:`/`closed_checks` sha discipline, requirement
  decomposition). None of `closed-checks-gate.sh`'s existing behavior is
  changed.
- Write set for phase 2 (frozen, for review before Approve):
  - rewrite `review/hooks/directive.sh` (deepen the four facet strings;
    still a stub sourcing `core_role_directive` — no local boilerplate
    regrowth, `stub-check.sh` keeps passing)
  - add `review/hooks/methodology-gate.sh` (new `PreToolUse` gate)
  - add `review/hooks/state.sh` (new `SessionStart` resume-context hook,
    informing only, mirrors the `implementation-rulebook` pattern named
    in the survey — not a gate)
  - edit `review/hooks/hooks.json` (register the two new hooks)
  - add `tests/methodology-gate-test.sh` (repo-level, pass/deny cases)
  - add `review/skills/finding-record/checklist.md` (the repeated
    per-requirement procedure, referenced from `SKILL.md`)
  - `docs/issue-39/reports/conformance-review.md` (phase-2 record,
    written after Approve)

## (a) Directive deepening — phase 1 / phase 2, per facet, executable

The current `directive.sh` states four one-line facets
(`YOU_DECIDE`/`USE_WHEN`/`PRODUCES`/`HAND_OFF`) with no phase split and
no stated prohibitions. This role, like every rulebook under contract
v3 s19, actually runs in two phases with different write surfaces and
different judgment calls in each — the directive should say so, at the
level `implementation-rulebook`'s own multi-hook briefing does, not
compress it back into one sentence.

**Phase 1 (proposal stage) — steps, judgment, prohibitions:**

1. *Step*: read the target artifact and its spec (issue, prior approved
   proposal, or code diff) and extract a discrete requirement list, or
   an explicit sampling derivation if the spec is too large to
   enumerate in full.
2. *Judgment criterion*: a requirement is "discrete" if it can be
   independently marked Present/Surface/Absent/Incorrect without
   depending on any other requirement's verdict; if two candidate
   requirements can never differ in verdict, merge them — do not
   inflate the count.
3. *Prohibition*: never render a verdict in phase 1. Phase 1 produces
   the requirement list and, if the review methodology requires a named
   evidence-gathering pass before verdicts (see (c) below), the
   evidence-gathering plan — never a Present/Absent call. Phase 1 is
   scoping, not judging.
4. *Prohibition*: never write outside `docs/issue-<n>/**` in phase 1.

**Phase 2 (record stage) — steps, judgment, prohibitions:**

1. *Step*: for every requirement in the phase-1 list, gather evidence
   from the artifact under review — never from the building agent's
   stated intent, never from a summary the builder wrote about their
   own work.
2. *Judgment criterion (independence)*: if the only available support
   for a verdict is the builder's own account (a commit message, a PR
   description, a "trust me" comment) with no artifact-side evidence
   locatable, the verdict is `Unverifiable`, not a favorable guess.
3. *Judgment criterion (verdict selection)*: `Present` requires the
   artifact evidence fully satisfies the requirement; `Surface` requires
   evidence of an imitation that does not actually satisfy it (e.g. a
   stub, a hardcoded pass-condition); `Incorrect` requires evidence that
   contradicts the requirement; `Absent` requires a confirmed negative
   (searched and not found); `Unverifiable` requires a stated, named
   reason access was unavailable (not just "didn't look").
4. *Prohibition*: never fix. A finding is `addressed_to:` the owning
   role and stops there.
5. *Prohibition*: never close a `closed_checks` cite against a sha other
   than the record's own `code_under_review:` (unchanged from
   `closed-checks-gate.sh`, restated here as directive-level guidance,
   not a new rule).
6. *Prohibition*: never render a holistic single verdict for a whole
   artifact — every verdict is per-requirement, per (a) above.

**Facet mapping (kept as four core-template arguments, not expanded
past the template's shape):**

- `YOU_DECIDE` — unchanged: the per-requirement, five-value verdict
  call.
- `USE_WHEN` — gains the phase split and independence prohibition
  inline (still one string, but a longer, more specific one — see
  frozen text in (d)).
- `PRODUCES` — gains an explicit phase-1/phase-2 split: phase 1 produces
  the requirement list (or sampling derivation); phase 2 produces the
  per-requirement verdicts with `spec_ref` + evidence pointer,
  `code_under_review:`, and sha-matched `closed_checks` cites (already
  the current text, restated with the phase split made explicit).
- `HAND_OFF` — gains the "never fixed here" prohibition already implicit
  but not spelled out as a standalone clause.

This keeps `stub-check.sh`'s structural check (source line +
`core_role_directive` call, four arguments, no regrown boilerplate)
passing — the deepening lengthens the four argument *strings*, it does
not add a fifth argument or inline logic.

## (b) Methodology gate — mechanical `PRODUCES` verification

New `review/hooks/methodology-gate.sh`, `PreToolUse` on
`Write|Edit|MultiEdit`, targeting exactly this role's own write
surfaces (mirrors `closed-checks-gate.sh`'s own path-resolution and
fail-closed-trap-at-top shape — same engineering pattern already in
this repo, not invented fresh):

- **Target surfaces**: `docs/issue-[0-9]+/proposals/.*\.md` written
  under this role's own subject tree (phase-1 proposals — checked only
  when `role: review` / `role: conformance-review` frontmatter or the
  branch name identifies this role, so the gate never fires on another
  role's proposal) and `docs/issue-[0-9]+/reports/(conformance-)?review
  \.md$` (the phase-2 record).
- **Required elements, checked against the resulting text** (extracted
  from `Write`'s `content` / `Edit`'s merged `old_string`→`new_string` /
  `MultiEdit`'s replayed edits — same extraction approach as
  `closed-checks-gate.sh` already uses):
  - *Phase-1 proposal*: a requirement list or an explicit sampling
    derivation is present (heuristic: a numbered/bulleted requirement
    enumeration, or the literal phrase "sampling derivation"); a
    **Constraints** section naming what this PR touches; if any
    methodology element from issue #30's proposal is cited as adopted,
    it must name its source (the gate checks for the presence of a
    source-attribution pattern near any "adopted" claim — not a full
    citation-graph check, which is a human judgment call the gate does
    not attempt).
  - *Phase-2 record*: at least one requirement block; every verdict
    token found (`Present`/`Surface`/`Absent`/`Incorrect`/
    `Unverifiable`, case-insensitive, word-boundary matched so
    "presently" or "absently" never false-positive) sits within a block
    that also carries a `spec_ref:` field and (unless the verdict is
    `Unverifiable`) an `evidence:` field; a `code_under_review:` or
    `upstream(_code_sha)?:` field is present whenever any
    `closed_checks`/`code_sha:` entry exists (this duplicates
    `closed-checks-gate.sh`'s own precondition on purpose — the two
    gates check different things about the same fact and either alone
    catching the gap is fine; belt-and-suspenders on a load-bearing
    invariant is deliberate, not redundant waste).
- **Never checked mechanically** (named explicitly so the gate's limits
  are not silently assumed away): the *correctness* of a verdict, the
  *quality* of an evidence pointer's argument, and the reviewer's actual
  behavioral independence from builder intent — these remain human/
  approver judgment calls; the gate only checks that the required
  *fields* exist, per the same limit `pricing-rulebook`'s
  `methodology-gate.sh` states for its own six-element check.
- **Fail-closed trap-at-top**, **kill switch**
  `REVIEW_METHODOLOGY_GATE_OFF=1`, **python3-required, fail-closed if
  absent** — same three properties every gate in this repo and its
  sibling rulebooks already share (`closed-checks-gate.sh`'s own header,
  `pricing/hooks/methodology-gate.sh`'s header). This is a convergent
  in-repo/in-family convention, not a new one being introduced.

## (c) Order enforcement — is there a sequence to track?

Checked against issue #30's own adopted methodology text
directly: the sequence is **extract/derive requirements (phase 1) →
gather evidence per requirement → render verdict (phase 2)**. This
sequence is already enforced by the **phase split itself** (contract
v3 s19: phase 1 and phase 2 are different PR states gated by Approve,
enforced by the human-approval mechanism, not by this role's own
hooks) and, within phase 2, by the methodology gate in (b): a verdict
token cannot appear without its `spec_ref`/`evidence` fields already
present in the *same* write, which structurally forces evidence to be
named at verdict-writing time rather than backfilled later.

**Decision: no separate state-tracking gate is proposed.** Unlike
`implementation-rulebook`'s `coding-progress-gate.sh` (which blocks a
*different* role's action — `git commit` — until a *third* artifact,
`verify.md`, reaches a state only another role can set), this role's
own sequence is a single-actor, single-artifact-type sequence with no
cross-actor state dependency; the phase-gate (human Approve) plus the
field-copresence check in (b) already prevent the one failure mode a
state file would guard against (a verdict written with no evidence
named). Adding a state file on top would duplicate, not add, coverage.

A lightweight, **non-gating** `review/hooks/state.sh`
(`SessionStart`, informing only — same shape as
`implementation-rulebook/coding/hooks/state.sh`) is still proposed,
purely to restate on resume which phase this subject is in and point at
the existing record, since that pattern already exists in this repo's
sibling rulebook and costs nothing (it never blocks).

## (d) Frozen directive text (phase 2 — not applied in this PR)

```bash
YOU_DECIDE="YOU DECIDE: whether what was built matches what was specified — a per-requirement verdict (Present|Surface|Absent|Incorrect|Unverifiable), never a holistic code-quality judgment, never a fix"
USE_WHEN="USE_WHEN: phase 1 — after a target artifact and spec are identified, to extract a discrete requirement list (or a stated sampling derivation), never to render a verdict; phase 2 — after Approve, working from the artifact and the spec only, deliberately without the building agent's stated intent; an unlocatable-evidence case is Unverifiable, never a favorable guess"
PRODUCES="PRODUCES (required record fields): phase 1 — requirement list or sampling derivation; phase 2 — per-requirement verdicts with spec_ref + diff-pointer evidence (Unverifiable may omit both, naming why), code_under_review:, closed_checks cites keyed to that sha"
HAND_OFF="HAND-OFF: findings addressed_to the owning role; never fixed here, never resolved by this role editing the target artifact"
```

## (e) Gate tests (phase 2 — design frozen now)

New `tests/methodology-gate-test.sh` (repo-level, pattern matches
`tests/run-gate-tests.sh`'s existing harness so it plugs into the same
runner without a bespoke second harness):

| # | Case | Input shape | Expected |
|---|------|-------------|----------|
| 1 | Phase-1 proposal, requirement list present, Constraints present | valid `docs/issue-N/proposals/review.md` write | allow (0) |
| 2 | Phase-1 proposal, no requirement list, no sampling derivation | same path, content missing both | deny (2) |
| 3 | Phase-2 record, one requirement block, `Present` verdict, `spec_ref:` + `evidence:` present | valid write | allow (0) |
| 4 | Phase-2 record, verdict token present, no `spec_ref:` in that block | otherwise-valid write | deny (2) |
| 5 | Phase-2 record, verdict `Unverifiable`, no `spec_ref`/`evidence`, reason stated | valid write | allow (0) |
| 6 | Phase-2 record, `closed_checks`/`code_sha:` present, no `code_under_review:`/`upstream:` | otherwise-valid write | deny (2) |
| 7 | Write to an unrelated path (another role's record, a source file) | any content | allow (0) — not this gate's business |
| 8 | `REVIEW_METHODOLOGY_GATE_OFF=1` set | otherwise-denying content | allow (0) — kill switch honored |
| 9 | Malformed/non-JSON stdin payload | garbage | deny (2) — fail-closed on unparseable input |
| 10 | `python3` unavailable (simulated via `PATH` override) | any | deny (2) — fail-closed, not fail-open |

Cases 2/4/6/9/10 are the deny-path floor; case 8 and case 7 are the two
required "does not over-fire" checks. This matches the shape
`tests/deny-only-check.sh` already enforces repo-wide (every gate must
have at least one exercised deny path) — the new gate is written to
satisfy that existing repo-level check, not to introduce a parallel
convention.

## (f) Agent / checklist

Issue #39 item 4 applies conditionally ("필요 시"). This role's
per-requirement verdict procedure *is* a repeated procedure (run once
per requirement, every time), so a checklist is warranted — a
dedicated `agents/` sub-agent is not: the procedure is a checklist
followed by the same session doing the review, not a separable task
handed to a different actor. Proposed: `review/skills/finding-record/
checklist.md`, referenced from `SKILL.md`'s existing text (added as a
"before writing this finding block" pointer, not duplicating the
skill's prose):

```markdown
# Per-requirement checklist (finding-record)

Before writing a verdict for this requirement, confirm:
- [ ] spec_ref names a stable locator (id, or heading+paragraph) — not
      the free-text requirement string itself.
- [ ] evidence is a pointer into the artifact (file:line/hunk) — not a
      paraphrase, not a summary of what the builder said they did.
- [ ] the verdict came from looking at the artifact, not from the
      builder's account of their own intent.
- [ ] if Unverifiable: the reason access was unavailable is named.
- [ ] if closed_checks are cited: code_sha matches this record's own
      code_under_review: (or upstream:), not the working branch HEAD.
```

## What is deliberately out of scope

- Any change to `closed-checks-gate.sh` — untouched, per the
  net-additive constraint above.
- A cross-role state-tracking gate (analogue of
  `coding-progress-gate.sh`) — this role has no cross-actor sequence
  dependency to enforce; see (c).
- Wiring `spec_ref`/verdict-vocabulary checks into core's
  `record-fields-gate.sh` — still core's write set (reaffirmed from
  issue #30's own "Record/gate reflection" note); this role's new
  `methodology-gate.sh` is the correct place for a role-specific check,
  exactly as `pricing`/`performance-engineering` each keep their own
  `methodology-gate.sh` rather than pushing into core's generic gate.
- Re-litigating which methodology to adopt — issue #30 already decided
  that; this issue mechanizes the decision, it does not reopen it.

## Alternatives considered

- **Push the new checks into `closed-checks-gate.sh` instead of a new
  file.** Rejected: that gate has one narrow, already-tested
  responsibility (sha-matching); folding an unrelated field-presence
  check into it would make one gate do two jobs and complicate its
  existing test coverage for no benefit — `pricing-rulebook` and
  `performance-engineering-rulebook` both keep their methodology checks
  in a dedicated `methodology-gate.sh` sibling to their own narrower
  gates, and this proposal follows that convention.
- **Add a state file / progress gate for the phase-1→phase-2 sequence.**
  Rejected in (c): the human-Approve phase gate already enforces the
  sequence at the level that matters; a role-local state file would
  duplicate coverage the field-copresence check in (b) already
  provides.
- **Skip the checklist, fold its content into `SKILL.md` prose only.**
  Rejected: `SKILL.md` already carries the field definitions; a
  separate short per-instance checklist is what
  `implementation-rulebook`'s own agent-facing procedures use for a
  repeated-per-item check (distinct artifact type from a one-time
  narrative skill doc) — kept as a small separate file so it can be
  read once per requirement without re-reading the full skill.

**Failure signal.** If this proposal is wrong: the methodology gate
starts denying legitimate writes that satisfy the methodology in a form
its heuristics don't recognize (e.g. a valid sampling derivation phrased
in words the gate's pattern-match misses), forcing reviewers into
gate-shaped prose rather than substantively-correct prose. If that is
observed within the next few subjects reviewed under the new gate, the
gate's heuristics should be loosened (or the kill switch used
temporarily) rather than the required fields themselves being dropped.

## How this will be judged

- `docs/issue-39/reports/conformance-review/current-state-survey.md` and
  `scout-brief.md` exist; the survey names every existing hook/skill
  file read this session and the scout-brief states the skip condition
  explicitly.
- This proposal names, for each new mechanism (directive deepening,
  methodology gate, order-enforcement decision, gate tests, checklist),
  which in-repo or sibling-rulebook precedent it is modeled on, and
  states at least one considered-and-rejected alternative per major
  design choice.
- No file outside `docs/issue-39/**` is modified by this PR.
- No canon script or sibling-rulebook script text is copied verbatim
  anywhere in this proposal or its frozen phase-2 text.
- Phase 2, once approved, adds exactly the write set frozen in
  "Constraints" above — no more, no fewer files — and
  `tests/methodology-gate-test.sh`'s ten cases in (e) all pass before
  the phase-2 record is written.
