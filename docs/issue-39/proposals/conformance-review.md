---
subject: issue-39
role: review
loop_state: scope-proposed
---

# Proposal: mechanize the adopted conformance methodology as a composable plugin set (issue #39)

## Request (paraphrased intent)

Issue #30 adopted (phase 1) and reflected (phase 2, the `spec_ref`
field — issues #37/#38) a conformance methodology for this role. That
reflection lives only as directive prose and skill text — nothing
mechanically checks a written record actually followed it. Issue #39
asks to close that gap. **Corrective feedback on the first version of
this proposal** (issue #39 comment thread, "요구 정정") rejected a
single deepened directive + one monolithic gate as the shape: the
required shape is a **plugin set**, one independent plugin per adopted
methodology (matching how `core` hosts `freelunch`/`scout` as separate,
freelunch-completeness-grade plugins rather than one do-everything
plugin), with "freelunch" completeness itself represented as its own
plugin/coverage concern, and with the phase-1 proposal norm and
phase-2 deliverable norm each expressed as a **combination of
plugins**, not folded into one file. This revision restructures the
proposal to that shape. See
`docs/issue-39/reports/conformance-review/current-state-survey.md` for
what exists today and `scout-brief.md` for why field-scouting was
skipped (the field question is already answered by issue #30; this
issue mechanizes that answer).

## Constraints

- **Phase-1 only.** This PR touches only `docs/issue-39/**`. No file
  under `review/`, `review-*/`, `tests/`, `.claude-plugin/`, or
  `install.sh` is created, deleted, or edited in this PR. Everything
  below section (b) is a frozen plan for phase 2, executed only after a
  human approver's Approve, per contract v3 s19.
- **No APPROVE in this PR.** This proposal does not, and cannot,
  approve itself; phase 2 opens only through the two paths contract v3
  s19 names.
- **Canon reference only, never copy** (core canon-scripts.md,
  reaffirmed by issue #31 and #34 in this repo — `stub-check.sh` is run
  by reference against the installed `core` plugin, never vendored).
  Nothing proposed here vendors a byte copy of any canon script.
  `pricing`/`performance-engineering`'s `methodology-gate.sh` files and
  `implementation-rulebook`'s `coding/hooks/{state,hunt-state,
  hunt-guard,coding-progress-gate}.sh` are read only for engineering
  pattern; no text from those files is reused verbatim anywhere below.
- **Role boundary / write_scope unchanged.** Every plugin below only
  ever inspects writes to this role's own phase-1 (`docs/issue-<n>/
  proposals/**`) and phase-2 (`docs/issue-<n>/reports/(conformance-)?
  review.md`) surfaces — never another role's.
- **Net-additive, never a relaxation.** Every check proposed below adds
  a mechanical floor under a requirement issue #30 already adopted in
  prose (five-value vocabulary, `spec_ref`, evidence pointer,
  `code_under_review:`/`closed_checks` sha discipline, requirement
  decomposition, deterministic severity table). None of
  `closed-checks-gate.sh`'s existing behavior is changed.

## (a) Plugin architecture — one methodology, one plugin

The corrected shape replaces "one role plugin with an internally
deepened directive and one gate" with **five self-contained plugins**,
each owning its own directive/gate/skill/test slice and each
independently registered in `.claude-plugin/marketplace.json`. A
plugin is "self-contained" in the sense issue #39's corrective feedback
uses: it may carry its own directive facets (where it has a distinct
`YOU_DECIDE`), its own `PreToolUse` gate, its own skill/checklist, and
its own gate-test file — it does not require another plugin's internals
to be read to understand what it enforces. Composition between plugins
happens only through the shared artifact surface (the same
`docs/issue-<n>/**` files), never through one plugin calling into
another's code.

### (a.1) Plugin list (required inventory)

| Plugin | Methodology / norm it owns | Components | Composes into |
|---|---|---|---|
| `review` | Role identity / phase protocol (not itself a conformance methodology — the composition root every other plugin plugs artifacts into) | `directive.sh` (four facets, phase-1/phase-2 split), `hooks.json`, `state.sh` (`SessionStart`, informing only) | Base for all norms below; every other plugin's gate fires only on writes this plugin's directive scopes to (`docs/issue-<n>/proposals/review.md`, `docs/issue-<n>/reports/(conformance-)?review.md`) |
| `review-traceability` | **Adopted methodology 1**: ISO 19011 / IIA evidence-based, independent, per-requirement conformance traceability (issue #30 (b), (c)) | `hooks/traceability-gate.sh` (`PreToolUse`, requirement-block + verdict-vocabulary + `spec_ref` + `evidence` field-copresence check — this is where issue #37/#38's `spec_ref` reflection actually lives), `skills/finding-record/` (unchanged from today, relocated), `tests/traceability-gate-test.sh` | **Phase-2 deliverable norm** (with `review-record-norm`, `review-severity`) |
| `review-severity` | **Adopted methodology 2**: deterministic severity table lookup (Chromium 5-band / Microsoft bug-bar shape), DREAD-style averaged scoring explicitly rejected (issue #30 (c), third bullet) | `hooks/severity-gate.sh` (`PreToolUse`, denies any severity value not drawn from the closed table — no numeric/averaged score pattern accepted), `skills/severity-classification/` (unchanged from today, relocated), `tests/severity-gate-test.sh` | **Phase-2 deliverable norm** (only when severity is in scope — issue #30 (b) states this is conditional) |
| `review-record-norm` | **Adopted methodology 3**: `code_under_review:`/`closed_checks` sha-matched evidence discipline | `hooks/closed-checks-gate.sh` (unchanged behavior, relocated from `review/hooks/` to its own plugin so the sha-discipline methodology is independently on/off-able and independently testable), existing tests | **Phase-2 deliverable norm** (with `review-traceability`, `review-severity`) |
| `review-proposal-completeness` | **freelunch-completeness bar for this role's own phase-1 output** — issue #30 (a)'s proposal-norm (Request / Constraints / sourced-adoption / adopt-vs-skip / "How this will be judged"), held to the same structural-completeness bar `core`'s `freelunch` plugin holds fan-out chunks to | `hooks/proposal-completeness-gate.sh` (`PreToolUse` on `docs/issue-<n>/proposals/review.md`, checks the five structural sections from issue #30 (a) are present), `tests/proposal-completeness-gate-test.sh` | **Phase-1 proposal norm** (standalone — this plugin alone is the phase-1 norm; `review-traceability`'s requirement-list check augments it, see (a.2)) |

Every plugin above gets its own `.claude-plugin/plugin.json` and its
own entry in `.claude-plugin/marketplace.json`'s `plugins` array
(phase 2; frozen shape below in (d)), exactly the way `core` lists
`freelunch` and `scout` as separate marketplace entries rather than one
merged plugin.

### (a.2) Norms as plugin composition (not a monolith)

Issue #39's corrective feedback specifically requires that the phase-1
proposal norm and the phase-2 deliverable norm each be **expressed as
which plugins combine to produce them** — this is the design's actual
content, not an afterthought:

- **Phase-1 proposal norm** (issue #30 (a), the "기획서 규범"): `review`
  (directive scoping: only fires on `docs/issue-<n>/proposals/review.md`
  under this role) **+ `review-proposal-completeness`** (the five
  required structural sections) **+ `review-traceability`**'s
  requirement-list/sampling-derivation check reused in its phase-1 mode
  (a proposal must extract a discrete requirement list before phase 2 —
  this is `review-traceability`'s methodology applied one phase early,
  not a duplicate check invented fresh). No severity or sha-discipline
  plugin participates in phase 1 — severity and `closed_checks` citation
  are phase-2-only concerns, so `review-severity` and
  `review-record-norm` correctly do not fire on a proposal write.
- **Phase-2 deliverable norm** (issue #30 (b)/(c), reflected via
  `spec_ref` per issues #37/#38, the "산출물 규범"): `review` (directive
  scoping to `docs/issue-<n>/reports/(conformance-)?review.md`) **+
  `review-traceability`** (per-requirement verdict, `spec_ref`,
  evidence pointer — this is where the issue #37/#38 `spec_ref`
  reflection is mechanically enforced) **+ `review-record-norm`** (sha
  discipline whenever `closed_checks` is cited) **+ `review-severity`**
  (conditionally, only when a severity value is present in the record).
  No single plugin alone produces the phase-2 norm; it is the
  conjunction of these four firing on the same write.

This replaces the prior version's single `methodology-gate.sh` (which
folded traceability, sha-discipline pre-condition, and structural
checks into one file) with four independently testable, independently
kill-switchable gates whose *composition*, not any one file, is the
enforced norm.

## (b) Per-plugin design (phase 2 — frozen, not applied in this PR)

### (b.1) `review` — directive deepening (unchanged from prior review, relocated)

`review/hooks/directive.sh` states four one-line facets
(`YOU_DECIDE`/`USE_WHEN`/`PRODUCES`/`HAND_OFF`) with no phase split.
Deepened to state the phase-1/phase-2 split and the prohibitions
explicit, at the level `implementation-rulebook`'s own multi-hook
briefing does — this facet content is unchanged from the previously
reviewed version of this proposal; only its scope shrinks (it no longer
also states methodology-specific `PRODUCES` detail belonging to
`review-traceability`/`review-severity`/`review-record-norm` — those
plugins state their own required-field text in their own directive
slice, per (b.2)-(b.4)):

```bash
YOU_DECIDE="YOU DECIDE: whether what was built matches what was specified — a per-requirement verdict (Present|Surface|Absent|Incorrect|Unverifiable), never a holistic code-quality judgment, never a fix"
USE_WHEN="USE_WHEN: phase 1 — after a target artifact and spec are identified, to extract a discrete requirement list (or a stated sampling derivation), never to render a verdict; phase 2 — after Approve, working from the artifact and the spec only, deliberately without the building agent's stated intent; an unlocatable-evidence case is Unverifiable, never a favorable guess"
PRODUCES="PRODUCES: phase 1 — requirement list or sampling derivation (checked by review-proposal-completeness + review-traceability); phase 2 — per-requirement verdicts (checked by review-traceability, review-record-norm, review-severity where applicable)"
HAND_OFF="HAND-OFF: findings addressed_to the owning role; never fixed here, never resolved by this role editing the target artifact"
```

`review/hooks/state.sh` (new `SessionStart`, informing only, mirrors
`implementation-rulebook`'s pattern) restates on resume which phase this
subject is in and which plugins' gates are therefore live for it.

### (b.2) `review-traceability` — mechanical per-requirement check

New `review-traceability/hooks/traceability-gate.sh`, `PreToolUse` on
`Write|Edit|MultiEdit`, mirroring `closed-checks-gate.sh`'s own
path-resolution and fail-closed-trap-at-top shape:

- **Target surfaces**: `docs/issue-[0-9]+/proposals/review\.md$` (phase
  1, requirement-list-only mode) and `docs/issue-[0-9]+/reports/
  (conformance-)?review\.md$` (phase 2, full mode) — scoped by this
  role's own `role:` frontmatter / branch identity so the gate never
  fires on another role's proposal.
- **Phase-1 mode**: a requirement list or an explicit sampling
  derivation is present (heuristic: numbered/bulleted requirement
  enumeration, or the literal phrase "sampling derivation").
- **Phase-2 mode**: at least one requirement block; every verdict token
  found (`Present`/`Surface`/`Absent`/`Incorrect`/`Unverifiable`,
  case-insensitive, word-boundary matched) sits within a block that also
  carries a `spec_ref:` field and (unless `Unverifiable`) an
  `evidence:` field. This is the sole mechanical enforcement point for
  the `spec_ref` field issues #37/#38 added to the record — kept in this
  plugin, not duplicated elsewhere.
- **Never checked mechanically**: the *correctness* of a verdict or
  evidence argument, or the reviewer's actual behavioral independence —
  human/approver judgment, stated explicitly so the gate's limits are
  not silently assumed.
- **Fail-closed trap-at-top**, kill switch
  `REVIEW_TRACEABILITY_GATE_OFF=1`, python3-required fail-closed if
  absent.

`review-traceability/skills/finding-record/` is the existing
`review/skills/finding-record/` directory, relocated (content
unchanged) so the skill lives alongside the gate that checks its
output, plus the per-requirement checklist from the prior version of
this proposal:

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

### (b.3) `review-severity` — deterministic table-lookup check

New `review-severity/hooks/severity-gate.sh`, `PreToolUse`, fires only
on phase-2 record writes that contain a severity field. Denies any
value not drawn from the closed Chromium-5-band/Microsoft-bug-bar
vocabulary already fixed by `severity-classification`'s skill text, and
denies any numeric or averaged-score pattern (a DREAD-shaped
`N.N`/`N/25` value), since issue #30 (c) names DREAD's abandonment as
the specific reason this methodology, not that one, was adopted. Kill
switch `REVIEW_SEVERITY_GATE_OFF=1`. `review-severity/skills/
severity-classification/` is the existing skill, relocated unchanged.

### (b.4) `review-record-norm` — sha discipline (relocated, unchanged behavior)

`review-record-norm/hooks/closed-checks-gate.sh` is today's
`review/hooks/closed-checks-gate.sh`, relocated to its own plugin with
identical behavior: a `code_under_review:` or `upstream(_code_sha)?:`
field is required whenever any `closed_checks`/`code_sha:` entry
exists. No logic changes — the previous version of this proposal
folded this precondition into one monolithic `methodology-gate.sh`;
this revision keeps the existing, already-tested file's behavior byte-
identical and only relocates it so the sha-discipline methodology has
its own plugin identity, its own kill switch
(`REVIEW_RECORD_NORM_GATE_OFF=1`, additive — the file's existing kill
switch name, if any, is preserved as an alias), and its own test file,
independent of `review-traceability`.

### (b.5) `review-proposal-completeness` — freelunch-grade phase-1 bar

New `review-proposal-completeness/hooks/proposal-completeness-gate.sh`,
`PreToolUse` on `docs/issue-[0-9]+/proposals/review\.md$`. This is the
plugin issue #39's feedback names explicitly as "freelunch 완성도" for
this role's own phase-1 output: it checks the same structural bar
`core`'s `freelunch` plugin holds a fan-out chunk to before accepting
it as complete, applied here to a phase-1 proposal:

- **Request** section present (paraphrased intent, not a verbatim issue
  quote — heuristic: section header match plus a length/quote-density
  check).
- **Constraints** section present, naming what this PR touches.
- Every "adopted"/"adopt" claim sits near a source-attribution pattern
  (named external source, landed spec, or prior in-repo research) —
  matching issue #30 (a)'s source-grounding requirement; not a full
  citation-graph check, which stays a human/approver judgment call.
- An explicit **adopt-vs-skip** split (both an "adopted" list and a
  "skipped"/"out of scope" list are present, each with at least one
  one-line reason).
- A **"How this will be judged"** section closes the document, itself
  containing at least one externally verifiable condition (file
  existence, gate exit code, field presence) rather than only prose.

Kill switch `REVIEW_PROPOSAL_COMPLETENESS_GATE_OFF=1`. This plugin has
no skill component (the bar is stated in issue #30 (a) and restated in
`review`'s own `USE_WHEN`, not owned by a separate skill file) — its
directive/gate/test triad alone is sufficient to be self-contained per
(a) above.

## (c) Order enforcement — is there a sequence to track?

Checked against issue #30's adopted methodology text directly: the
sequence is **extract/derive requirements (phase 1, `review-proposal-
completeness` + `review-traceability` phase-1 mode) → gather evidence
per requirement → render verdict (phase 2, `review-traceability` +
`review-record-norm` + `review-severity`)**. This sequence is enforced
by the **phase split itself** (contract v3 s19: phase 1 and phase 2 are
different PR states gated by human Approve) and, within phase 2, by
`review-traceability`'s field-copresence check: a verdict token cannot
appear without its `spec_ref`/`evidence` fields already present in the
same write, structurally forcing evidence to be named at verdict-
writing time.

**Decision: no separate cross-plugin state-tracking gate is proposed.**
Unlike `implementation-rulebook`'s `coding-progress-gate.sh` (blocks a
*different* role's action until a *third* artifact reaches a state only
another role can set), this role's sequence is single-actor,
single-artifact-type, with no cross-actor state dependency; the
human-Approve phase gate plus the field-copresence checks already
prevent the one failure mode a state file would guard against. `review`'s
own `state.sh` (b.1) remains a non-gating, informing-only restatement of
which phase — and therefore which plugins are live — a subject is in.

## (d) Marketplace registration (phase 2 — frozen)

`.claude-plugin/marketplace.json`'s `plugins` array gains four new
entries alongside the existing `review` entry (unchanged text, scope
note trimmed to reflect the split):

```json
{
  "name": "review",
  "source": "./review",
  "description": "Role identity and phase protocol for the review role on contract v3 (directive facets, phase-1/phase-2 write scoping, resume-state hook). Methodology enforcement lives in the sibling review-traceability/review-severity/review-record-norm/review-proposal-completeness plugins."
},
{
  "name": "review-traceability",
  "source": "./review-traceability",
  "description": "Per-requirement conformance traceability (ISO 19011/IIA evidence-based, independent verdicts; spec_ref + evidence field enforcement, issues #30/#37/#38)."
},
{
  "name": "review-severity",
  "source": "./review-severity",
  "description": "Deterministic severity table-lookup enforcement (Chromium/Microsoft bug-bar shape); denies DREAD-style averaged scores."
},
{
  "name": "review-record-norm",
  "source": "./review-record-norm",
  "description": "code_under_review: / closed_checks sha-matched evidence discipline for phase-2 review records."
},
{
  "name": "review-proposal-completeness",
  "source": "./review-proposal-completeness",
  "description": "freelunch-grade structural completeness bar for this role's own phase-1 proposals (Request/Constraints/sourced-adoption/adopt-vs-skip/How-this-will-be-judged)."
}
```

Each new plugin directory gets its own minimal `.claude-plugin/
plugin.json` (name + description, same shape as today's
`review/.claude-plugin/plugin.json`).

## (e) Gate tests (phase 2 — design frozen now)

Each plugin ships its own test file (pattern matches `tests/run-gate-
tests.sh`'s existing harness so all four plug into the same runner):

| File | Cases (abbreviated; full deny/allow/kill-switch/fail-closed table per file at phase-2 time) |
|---|---|
| `review-traceability/tests/traceability-gate-test.sh` | phase-1 requirement-list present/absent; phase-2 verdict-with-`spec_ref`/`evidence` present/absent; `Unverifiable` with stated reason allowed without those fields; unrelated path allowed; `REVIEW_TRACEABILITY_GATE_OFF=1` allowed; malformed stdin denied; missing python3 denied |
| `review-severity/tests/severity-gate-test.sh` | table value allowed; numeric/averaged value denied; no-severity-present allowed (not this gate's business); kill switch; fail-closed cases |
| `review-record-norm/tests/closed-checks-gate-test.sh` | existing test file, relocated unchanged (behavior byte-identical to today's `closed-checks-gate.sh`) |
| `review-proposal-completeness/tests/proposal-completeness-gate-test.sh` | all five structural sections present, allowed; each section individually missing, denied (five deny cases); kill switch; fail-closed cases |

Cases marked "denied" are the deny-path floor `tests/deny-only-check.sh`
already requires per gate repo-wide; each file independently satisfies
it rather than relying on another plugin's test file to cover its own
deny path.

## What is deliberately out of scope

- Any change to the *behavior* of today's `closed-checks-gate.sh` logic
  — only its plugin home moves, per (b.4).
- A cross-plugin/cross-role state-tracking gate (analogue of
  `coding-progress-gate.sh`) — see (c).
- Wiring `spec_ref`/verdict-vocabulary checks into core's
  `record-fields-gate.sh` — still core's write set, reaffirmed from
  issue #30's own note.
- Re-litigating which methodology to adopt — issue #30 already decided
  that; this issue mechanizes the decision as a plugin set, it does not
  reopen the methodology choice.
- A single merged `review` plugin housing all four methodology gates —
  explicitly rejected by issue #39's corrective feedback; see
  Alternatives.

## Alternatives considered

- **One role plugin (`review`) with one deepened directive and one
  `methodology-gate.sh` folding traceability + sha-discipline +
  structural checks together.** This was the prior version of this
  proposal. Rejected per issue #39's "요구 정정": it does not give each
  adopted methodology an independent, kill-switchable, separately
  testable identity, and it has no dedicated freelunch-completeness
  concern or explicit plugin inventory.
- **Push the new checks into `closed-checks-gate.sh` instead of new
  plugins.** Rejected: that gate has one narrow, already-tested
  responsibility (sha-matching); folding traceability/severity/
  structural checks into it would make one gate do four jobs.
- **Add a state file / progress gate for the phase-1→phase-2 sequence.**
  Rejected in (c): the human-Approve phase gate already enforces the
  sequence; a role-local state file would duplicate coverage the
  field-copresence check in `review-traceability` already provides.
- **Skip the checklist, fold its content into `SKILL.md` prose only.**
  Rejected: a separate short per-instance checklist is what
  `implementation-rulebook`'s own agent-facing procedures use for a
  repeated-per-item check — kept small so it can be read once per
  requirement.

**Failure signal.** If this proposal is wrong: either (a) the plugin
split proves to be over-decomposition — reviewers of a subject end up
needing to read all five plugins to understand one check, defeating the
"read one file to understand one methodology" goal — in which case
`review-severity` and `review-record-norm` (the two smallest, most
tightly coupled to `review-traceability`'s phase-2 firing condition)
should be the first candidates folded back; or (b) any gate starts
denying legitimate writes its heuristics don't recognize, in which case
that gate's own kill switch is used temporarily rather than the
required fields being dropped. Either failure should surface within the
next few subjects reviewed under the new plugin set.

## How this will be judged

- `docs/issue-39/reports/conformance-review/current-state-survey.md` and
  `scout-brief.md` exist; the survey names every existing hook/skill
  file read this session and the scout-brief states the skip condition
  explicitly.
- This proposal contains an explicit plugin-list table (a.1) naming,
  for every plugin: its name, the methodology or norm it owns, its
  components, and which composed norm(s) it participates in.
- The phase-1 proposal norm and phase-2 deliverable norm are each
  stated as an explicit combination of named plugins (a.2), not folded
  into one file's behavior.
- "freelunch" completeness is represented by its own named plugin
  (`review-proposal-completeness`, b.5) with its own gate and test file,
  not as a clause inside another plugin's check.
- No file outside `docs/issue-39/**` is modified by this PR.
- No canon script or sibling-rulebook script text is copied verbatim
  anywhere in this proposal or its frozen phase-2 text.
- Phase 2, once approved, adds exactly the plugin directories and files
  frozen in (b)-(e) above — one `.claude-plugin/plugin.json` per new
  plugin, one gate + one test file per methodology/norm, four new
  `plugins` entries in `.claude-plugin/marketplace.json` — no more, no
  fewer, and every plugin's own test file's deny/allow/kill-switch/
  fail-closed cases pass before the phase-2 record is written.
