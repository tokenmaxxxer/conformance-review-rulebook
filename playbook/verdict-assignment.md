---
axis: verdict-assignment
rule_count_floor: 3
---

# Verdict assignment

Choosing among Present | Surface | Absent | Incorrect | Unverifiable once
evidence for a requirement has been located (or not).

## Rules

1. **When** the artifact implements the requirement's literal wording but a
   check of the surrounding code shows it does not fire on the actual
   condition the requirement names (e.g. a validator exists but is never
   called on the input path the requirement describes), **assign Surface, not
   Present** — a Present verdict is reserved for evidence that the requirement
   is both implemented and reachable/active, not merely that matching code
   exists somewhere. source: RTM verification-link discipline — a
   verification link must trace to the requirement actually being satisfied,
   not just to an artifact that shares its vocabulary. ([Jama Software:
   Traceability Matrix guide](https://www.jamasoftware.com/requirements-management-guide/requirements-traceability/traceability-matrix/))

2. **When** the artifact does something that contradicts the requirement's
   stated condition (not merely omits it — actively does the opposite, e.g.
   requirement says "reject empty input", code accepts it), **assign
   Incorrect, not Absent** — Absent is reserved for no attempt found; a
   present-but-wrong implementation is a distinct failure mode a builder needs
   to know is different from "not started." source: standard defect-severity
   practice distinguishing missing-feature from wrong-behavior defects, which
   this role's own verdict taxonomy already encodes.

3. **When** the only evidence for a requirement lives in a location the review
   session cannot read (a third-party service's internal behavior, a
   production log not checked into the repo, a runtime the session has no
   access to), **assign Unverifiable and name the specific missing evidence
   location** — never render a favorable guess (Present) or an unfavorable
   guess (Absent) from absence of access; both are fabrications of confidence
   the session does not have. source: this role's own spec directive
   ("an unlocatable-evidence case is Unverifiable, never a favorable guess").

4. **When** a prior review record already marked a requirement Present at an
   earlier commit and the diff between that commit and the current one does
   not touch any file the requirement's evidence lives in, **carry the prior
   verdict forward without re-deriving it from scratch** — re-running full
   inspection on unchanged evidence wastes review effort without changing the
   outcome; cite the prior record's commit sha as the verdict's basis instead.
   (removal) source: RTM continuous-maintenance practice — traceability is
   "a daily habit," meaning links persist and get referenced, not rebuilt
   wholesale each pass. ([Jama Software: Traceability Matrix guide](https://www.jamasoftware.com/requirements-management-guide/requirements-traceability/traceability-matrix/))

5. **When** assigning Incorrect or Absent, **name the specific clause of the
   requirement that the evidence fails to satisfy**, not a bare verdict
   label — "Incorrect" alone tells the owning role a requirement failed but
   not which of its clauses to fix, forcing them to re-derive the same
   comparison the review already made. State the failing clause the same way
   a passing requirement's evidence citation is stated, so the verdict is
   itself actionable without a follow-up question.

6. **When** an Absent or Incorrect verdict rests on a single-pass reading of
   evidence that could plausibly be a false positive (a near-miss name match,
   a stale reference, a path that resolves to the wrong artifact version),
   **re-check that specific evidence once against the current artifact state
   before finalizing the verdict**, rather than asserting it on the first
   pass — a defect claim that turns out to be a false positive costs the
   owning role more rework than one extra confirmation pass costs the
   reviewer. source: false-positive-verification practice in security-audit
   tooling, which gates a finding behind a dedicated re-check step before it
   is reported rather than trusting the first detection.
