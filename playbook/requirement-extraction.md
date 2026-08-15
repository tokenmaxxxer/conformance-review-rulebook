---
axis: requirement-extraction
rule_count_floor: 3
---

# Requirement extraction

Decomposing a spec/issue into a discrete, checkable requirement list — phase 1
of a conformance-review pass, before any verdict is rendered.

## Rules

1. **When** a requirement sentence bundles more than one obligation with "and"/
   "또한" across independent clauses (e.g. "the API validates input and logs
   rejected requests"), **split** it into one line item per obligation before
   listing — a bundled line lets a partial build score as one Present instead
   of surfacing the missing half. source: ISO/IEC/IEEE 29148 requirement
   characteristic "singular" (one requirement, one testable statement).
   ([SEBoK: ISO/IEC/IEEE 29148](https://sebokwiki.org/wiki/ISO/IEC/IEEE_29148))

2. **When** a requirement statement carries no observable success condition
   (a noun phrase or goal with no measurable trigger — "the system should be
   fast", "errors are handled gracefully"), **flag it unverifiable-as-written**
   and request the missing acceptance threshold rather than inventing one —
   do not silently substitute your own numeric bar. source: requirements
   ambiguity/testability literature — checklists catch single-sentence
   ambiguity but require an explicit missing-criterion flag, not a filled-in
   guess. ([Kamsties, Berry & Paech, "Detecting Ambiguities in Requirements
   Documents Using Inspections"](https://cs.uwaterloo.ca/~dberry/FTP_SITE/reprints.journals.conferences/KamstiesBerryPaech2001DetectingAmbiguity.pdf))

3. **When** a requirement is itself a derived/summary line restating three or
   more sub-points already listed elsewhere in the same spec, **drop the
   summary line from the checkable list** and keep only its sub-points — a
   redundant top-level item double-counts coverage in the completeness ratio
   and inflates N without adding a new check. (removal) source: ISO/IEC/IEEE
   29148 "unambiguous"/"consistent" characteristics — a requirement set with
   duplicated obligations fails the standard's own consistency check.
   ([Well-Architected Guide: ISO/IEC/IEEE 29148 SRS template](https://www.well-architected-guide.com/documents/iso-iec-ieee-29148-template/))

4. **When** an issue's acceptance section already states a sampling derivation
   instead of a full enumeration (e.g. "spot-check 5 of 40 files"), **use the
   stated derivation verbatim as the requirement list's scope** rather than
   re-deriving your own N — re-deriving silently changes what "complete" means
   mid-review. source: this repo's own record-format convention (a derived:
   line must cite the actual command/path that produced a count claim).

5. **When** one requirement's check-worthiness or expected verdict is
   conditional on another requirement's outcome (e.g. "requirement B only
   applies if requirement A's flag is enabled"), **keep each as its own list
   item and state the dependency inline**, rather than merging B into A's
   line or silently dropping B when A doesn't obviously apply — a merged or
   dropped conditional requirement disappears from the checkable list instead
   of surfacing as a requirement whose applicability itself needs a verdict.

6. **When** extracting a requirement, **tag it with its dimension type**
   (functional behavior, error-handling, edge-case, or scope-boundary) rather
   than leaving every extracted item in one undifferentiated list — a
   requirement list with no dimension tags cannot show whether error-handling
   or edge-case coverage was actually sampled, only that some N requirements
   were checked overall. source: specification-readiness scoring practice
   that grades a spec across named dimensions (problem statement, scope,
   acceptance criteria, error handling, edge cases) separately rather than as
   one undifferentiated completeness score.
