---
status: landed
files:
  - README.md
  - review-cycle/hooks/state-gate.sh
  - review-cycle/hooks/run-gate-tests.sh
---

# Bring review's handoff protocol up to contract v2 (blackboard/event model)

## Intent

`docs/specs/role-handoff-contract.md` landed at commit `b240ec4` as the
authority spec (status: `final`) and replaces the v1 one-shot
parcel-handoff model (ACCEPTS/refuse-at-handoff) with a shared blackboard
each role reads, writes its own record onto, and wakes from. Review's own
docs have not been updated to match: `README.md`'s "Handoff protocol"
section (lines 106–161) still speaks in v1's ACCEPTS/WHERE UPSTREAM
LIVES/PRODUCES/STOPS vocabulary, and `review-cycle/hooks/state-gate.sh`
still enforces a v1 accepted-kind read-refusal (`ACCEPTED_KINDS =
{"build-proposal", "hypothesis", "feasibility-record"}`, function
`refuse_if_unaccepted_kind`, lines 182–232) that the v2 contract's §4
READ-broad rule directly contradicts: "Every role may read every other
role's record, unconditionally, for context. Reading something is never
itself a violation."

This is a **proposal only**. It commissions the rewrite; it does not
perform it. No file outside this one is touched by landing this document.

## What is being commissioned

### 1. `README.md` — rewrite the "Handoff protocol" section (lines 106–161)

Replace the four v1 headings (ACCEPTS / WHERE UPSTREAM LIVES / PRODUCES /
STOPS) with the v2 shape below. Keep the opening paragraph (lines 108–114)
that points at the work repo's own `docs/specs/role-handoff-contract.md`
as the resolved authority — that indirection is still correct under v2,
only the vocabulary it introduces needs to change.

**a. WAKES-ON (replaces ACCEPTS, contract §3).** Delete the current
ACCEPTS block (lines 116–124), which frames review's job as accepting or
refusing artifacts by declared `kind` at read time. Replace it with a
single row, quoted from contract §3's table: "review wakes on any commit
landed by coding." Note explicitly that this is a change in kind, not
just wording — v1 asked "may review read this artifact at all," v2 asks
"does the board's current state satisfy review's trigger row," and those
are different questions answered by different mechanisms (§4 governs the
first, now unconditionally yes; §3 governs the second).

**b. READ / DEPENDS-ON / NEVER-OVERWRITE (replaces WHERE UPSTREAM LIVES,
contract §4 and §11).** Three explicit subsections:

- *READ (broad).* Quote contract §4 directly: review may read every other
  role's record unconditionally, for context, including `hypothesis`'s
  and `build-proposal`'s narrative sections (`## Request`, `## Constraints`,
  `## What will be done`, `## Out of scope`) freely — reading them is
  never itself a violation. This reverses the current README text at
  lines 119–121 ("Must refuse any artifact declaring `kind` in
  `{hypothesis, build-proposal}` when read for its narrative body") and
  the state-gate.sh Rule 2 behavior described below.
- *DEPENDS-ON (narrow, contract §4).* State precisely, per the contract's
  own review-specific carve-out: review depends on `build-proposal` (the
  change) to decide what should exist. For a finding's `spec_vs_built`
  judgment specifically, review may depend only on the finished change as
  built and the `build-proposal`'s stated `files:`/sections — never on
  `hypothesis`'s aspirational narrative standing in for what was actually
  specified. This must be written out explicitly as its own callout
  (quote contract §4's own words: "Reading the narrative is allowed;
  building `spec_vs_built` on it alone is not") since the contract itself
  flags this as the most nuanced DEPENDS-ON rule it states.
- *NEVER-OVERWRITE (contract §11, unchanged from v1 §7 per contract §4's
  own note).* Review writes only
  `docs/reports/records/<subject>/review.md` (`kind: review-record`,
  including inline `finding` blocks). Carry forward the existing STOPS
  rule (README lines 156–158) that finding an existing record already at
  a path review does not own is refused and reported, never overwritten
  — this rule is unchanged by v2, only its section label moves.

**c. Blackboard record spec (replaces PRODUCES, contract §7 + §2's table
row for `review-record`).** State the `loop_state` vocabulary verbatim
from contract §2's table: `idle,scoped,auditing,draft-reported,reported`.
Note explicitly, quoting the table's dash entry for `review-record`'s
"required fields beyond common header" column, that review-record has
**no required fields beyond the common header** (contract §1) — this is
a narrowing from the current README (lines 138–140), which additionally
requires `handoff_status: provisional | final`; that field does not
appear in the v2 table row and should be dropped unless a separate
decision is made to keep it as a review-local extension (flag this as an
open question for the person landing the rewrite, not a call this
proposal makes).

**d. Finding back-edge participation (contract §5, §2's `finding` row).**
Rewrite the current finding paragraph (README lines 141–148) to state:
review is a major finding producer; findings addressed to coding (and
potentially other roles, since v2 generalizes the finding mechanism to
all six roles per §5) live as inline blocks within `review.md` itself —
never as separate files — per contract §2's `finding` row: "inline block
within the addressing role's own record." Required finding fields,
quoted from the same table row: `requirement`, `verdict`
(`Present|Surface|Absent|Incorrect|Unverifiable`), `evidence`,
`rationale`, `spec_vs_built` (required only when `verdict: Incorrect`),
`addressed_to: <role>`, `severity: blocking|advisory` — the last two are
new fields not in the current README's finding field list (line
142–144) and must be added. Also add, per contract §5's response schema:
when review itself closes a finding addressed to review, its
`review.md` must carry a `finding-response` entry with the finding
reference, the action taken or decline reason, and — when code changed —
proof of the fix.

**e. Loop-termination rule (contract §6).** Add a short closing note: a
wake is consumed only by writing the resulting record entry (a
`loop_state` change, a new `finding`, or equivalent); an unchanged board
wakes no one. This replaces any implicit v1 assumption that a review
session's mere reading of a changed artifact was itself sufficient
handoff activity.

Retain the "Kill switch" and "Repo layout" sections unchanged — they are
not part of the handoff protocol and contract v2 does not touch them.

### 2. `review-cycle/hooks/state-gate.sh` — rewrite to match

**a. Delete Rule 2 (the accepted-kind read refusal).** The block at lines
24–36 (comment) and lines 182–232 (implementation: `ACCEPTED_KINDS`,
`KIND_RE`, `declared_kind`, `refuse_if_unaccepted_kind`,
`READ_PATH_KEYS`, and the `if tool in READ_PATH_KEYS` / `if tool ==
"Bash"` blocks that invoke it) directly implements the v1 accept/refuse
row this contract abolishes. Contract §4's READ-broad rule makes this
whole rule a conformance violation, not a stricter-than-required
tightening — it must be deleted outright, not merely loosened. No
replacement read-refusal logic is warranted; §4 states reads are never
themselves a violation for any role.

**b. Narrow the gate's remaining job to three things**, restated from the
current file's own rules 0 and 1:

  - *(a) Write-path ownership.* Keep and rename "Rule 1" (lines 234–510):
    refusing writes that reach `review-record.md` outside a legal
    transition remains in scope as the mechanical half of contract §11's
    never-overwrite rule for review's own owned path,
    `docs/reports/records/<subject>/review.md`. Flag for the implementer
    that the current gate is hardcoded to a single flat `review-record.md`
    at repo root (`state_name` default, `REVIEW_RECORD_NAME` env var) —
    conforming to contract §2/§11's actual path
    (`docs/reports/records/<subject>/review.md`, subject-scoped) is a
    second, separable piece of work this proposal also commissions but
    does not design: the implementer must decide how `<subject>` is
    resolved by the gate (e.g. from an env var, from a single
    in-flight-subject convention, or by scanning) and record that
    decision when landing this section.
  - *(b) DEPENDS-ON violations, where mechanically detectable.* This
    proposal commissions an explicit assessment, to be written into the
    landed gate's own header comment, of whether the gate can ever
    mechanically catch a `spec_vs_built` finding built on `hypothesis`
    narrative alone rather than on `build-proposal`/built code. The
    likely answer, which the implementer should confirm rather than
    assume: **no** — this is a judgment about what evidence a role cited
    to reach a conclusion, not a structural property of a write's target
    path or content shape, so it is not mechanically checkable the way
    Rule 1's transition-table lookup is. Document this as a
    documentation-only rule per contract §14's "mechanical checks are not
    substantive checks" — specifically its line "no mechanical check in
    this contract enforces [path ownership]... a structural guarantee
    this contract's prose implies but that no hook actually provides
    unless the role's own rulebook adds one." The gate should not attempt
    to add heuristic detection for this (e.g. grepping a finding block
    for whether it mentions `hypothesis`) since that would be exactly the
    kind of check contract §14 warns produces false confidence.
  - *(c) Repo-local contract presence.* Keep Rule 0 (lines 38–45,
    168–180) unchanged: before anything else, the gate resolves the git
    root of the current working directory and refuses every
    handoff-protocol-relevant tool call if
    `docs/specs/role-handoff-contract.md` is absent there, rather than
    silently passing. This rule is untouched by the v1→v2 contract
    change and should be carried over verbatim, including its comment
    block.

**c. Fix the `kind:` parsing regex tolerance bug.** Contract §2 states:
"`kind` parsing by any gate must tolerate a trailing comment on the line
(`kind: build-proposal  # re-scoped`); a regex anchored to end-of-line
with no comment tolerance is a gate defect, not a contract violation by
the record's author." The current gate's regex, at line 185:

```python
KIND_RE = re.compile(r"^kind:\s*(\S+)\s*$", re.M)
```

is exactly this defect: because it is anchored with `$` after only
`\s*`, a line like `kind: review-record  # re-scoped` fails to match at
all (the trailing `# re-scoped` text is neither whitespace nor part of
`\S+`), so `declared_kind()` silently returns `None` instead of
`"review-record"` — a silent bypass, not a refusal, on exactly the input
contract §2 names. Since this proposal also commissions deleting Rule 2
(the only current caller of `KIND_RE`/`declared_kind`), the immediate
fix is to delete this regex along with Rule 2. However, flag for the
implementer that if any future rule in this gate (or a sibling
rulebook's gate) needs to parse a `kind:` line again — e.g. for a
`kind`-scoped write-ownership check — the fix is to change the pattern to
tolerate a trailing `#...` comment, e.g.
`re.compile(r"^kind:\s*(\S+)\s*(?:#.*)?$", re.M)` (matching the same
tolerant shape already used elsewhere in this same file for `status:`
parsing at line 405: `re.findall(r"^status:\s*(.*?)\s*(?:#.*)?$", text,
re.M)` — that existing pattern is the template to copy, not a new
invention).

**d. `review-cycle/hooks/run-gate-tests.sh` — flag, do not write.** This
proposal notes that landing (a)+(b)+(c)+(regex fix) above will make
several existing tests obsolete or wrong once Rule 2 is deleted: none of
the current test cases (a)–(l) in `run-gate-tests.sh` exercise Rule 2
(the accepted-kind read refusal) directly, so no existing PASS/FAIL case
needs deletion — but new coverage will be needed for: (1) a `Read`/`Grep`
call targeting a `hypothesis`- or `build-proposal`-kind file must now be
**allowed** where it was previously denied (no such case exists today
since the current suite only exercises Rule 0 and Rule 1 write paths);
(2) if the write-path is renamed/re-scoped to the subject-directory form
per item (a) above, every `write_state`/`new_root` helper and every
payload's `file_path` in the current suite (all currently targeting a
flat `$root/review-record.md`) will need updating in lockstep. This
proposal commissions that test-file update as follow-on work once the
gate rewrite lands; it does not specify the new test cases here.

## Write set

Exact files this proposal commissions changing, and nothing else:

- `/home/jwjung/tokenmaxxxer/review-agent-rulebook/README.md` — replace
  the "Handoff protocol" section (current lines 106–161) per item 1
  above; no other section of this file changes.
- `/home/jwjung/tokenmaxxxer/review-agent-rulebook/review-cycle/hooks/state-gate.sh`
  — delete Rule 2 in full (comment block lines 24–36; implementation
  lines 182–232 including `ACCEPTED_KINDS`, `KIND_RE`, `declared_kind`,
  `refuse_if_unaccepted_kind`, `READ_PATH_KEYS`, and both call sites);
  keep Rule 0 (lines 38–45, 168–180) and Rule 1 (lines 234–510)
  unchanged in behavior, updating only the header comment to document
  the DEPENDS-ON-is-not-mechanically-checkable finding from item 2(b);
  resolve (or explicitly defer, with a recorded decision) the
  flat-vs-subject-scoped `review-record.md` path question from item
  2(a).
- `/home/jwjung/tokenmaxxxer/review-agent-rulebook/review-cycle/hooks/run-gate-tests.sh`
  — flagged only, per item 2(d): update test coverage once the gate
  rewrite lands, to add the now-allowed-read cases and to follow any
  path rename. This proposal does not specify or write the new test
  cases.

## Out of scope

- No code is written or edited by landing this proposal document itself
  — it is a proposal, not the implementation.
- No build, no commit of the changes it describes.
- `docs/specs/role-handoff-contract.md` itself is not touched — it is
  treated as the fixed authority.
- The other five sibling `<role>-agent-rulebook` repositories (coding,
  qa, feasibility, product, ops) — each needs its own, separate,
  per-repo conformance proposal per the contract's own framing ("Landing
  this contract in each rulebook is separate, one proposal per repo").
- Deciding the subject-scoping mechanism for
  `review-cycle/hooks/state-gate.sh`'s state-file path (flagged in item
  2(a) as a decision for whoever lands the rewrite, not settled here).
- Writing the new/updated `run-gate-tests.sh` cases (flagged in item
  2(d), not written here).
- `review-cycle/skills/review-cycle/` and any other review-cycle files
  not named in the write set above — not read or assessed for v2
  conformance by this proposal.

## How you will know it worked

`README.md`'s "Handoff protocol" section reads in WAKES-ON /
READ-DEPENDS-ON-NEVER-OVERWRITE / blackboard-record-spec /
finding-back-edge / loop-termination shape, matching contract §§3–7
section-for-section, with no remaining ACCEPTS/WHERE-UPSTREAM-LIVES/
PRODUCES/STOPS vocabulary. `state-gate.sh` no longer refuses any read by
declared `kind`; Rule 0 and the write-ownership half of Rule 1 still
function; the gate's header comment states explicitly that DEPENDS-ON
violations for `spec_vs_built` are not mechanically detectable. A grep
for `ACCEPTED_KINDS`, `refuse_if_unaccepted_kind`, or
`{"build-proposal", "hypothesis", "feasibility-record"}` across the repo
after landing returns nothing.

## What did not work

- A literal repo-wide grep for `ACCEPTED_KINDS` / `refuse_if_unaccepted_kind`
  after landing does **not** return nothing, contrary to the letter of "How
  you will know it worked" above: this proposal document itself quotes
  those identifiers (in `## Intent` and item 2(a)) to describe what was
  deleted, and a proposal file is not something this change is permitted to
  edit away (the write set names only `README.md`, `state-gate.sh`, and
  `run-gate-tests.sh`). The intended check should be read as scoped to
  `review-cycle/hooks/state-gate.sh` (its actual target), not the literal
  repo tree; confirmed by grepping the hook file alone, which returns
  nothing.
- Considered fixing `KIND_RE` in place per the proposal's fallback
  instruction ("if nothing still reads KIND after Rule 2 is gone, remove
  KIND_RE entirely instead"). Confirmed `declared_kind`/`KIND_RE` had no
  remaining caller once `refuse_if_unaccepted_kind` and the two `if tool in
  ...` blocks were removed, so `KIND_RE` was deleted outright along with
  Rule 2 rather than patched — no dead code retained for a hypothetical
  future caller.
- Did not attempt the subject-scoping resolution for Rule 1's state-file
  path (flat `review-record.md` vs. `docs/reports/records/<subject>/
  review.md`) — the proposal explicitly defers this as separate follow-on
  work (item 2(a), "Out of scope"), so Rule 1's path behavior was left
  unchanged and the gap flagged in the header comment instead of guessed
  at.
- Did not write new `run-gate-tests.sh` cases for the now-allowed reads —
  the proposal flags this as commissioned-but-not-specified follow-on work
  (item 2(d)), not something this landing writes.
