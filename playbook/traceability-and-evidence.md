---
axis: traceability-and-evidence
rule_count_floor: 3
---

# Traceability and evidence citation

How a verdict's evidence gets recorded so a reader can re-derive it, and how
forward/backward links stay honest.

## Rules

1. **When** citing evidence for a verdict, **cite file:line-range plus the
   commit sha the review actually read**, not a file path alone — a bare path
   citation goes stale the moment the file changes again and cannot be
   re-verified against what the reviewer actually saw. source: RTM
   forward-traceability discipline (link requirement -> the specific artifact
   that satisfies it, not the containing module). ([ReqView: RTM for Systems
   Engineers](https://www.reqview.com/blog/requirements-traceability-matrix/))

2. **When** a requirement's evidence spans multiple files (e.g. a validation
   rule split across a schema file and a handler), **record one traceability
   link per contributing file**, not a single link to whichever file was
   found first — a single-link record under-documents the requirement and
   leaves the other files' contribution unverifiable to a later reader.
   source: RTM "Satisfaction links" / "V&V links" model treats each
   contributing artifact as its own link, not a bundled reference.
   ([Inflectra: Requirements Traceability](https://www.inflectra.com/Ideas/Topic/Requirements-Traceability.aspx))

3. **When** backward-tracing a requirement to confirm it originated from an
   actual stated need (not an invented one), **verify the requirement's
   source line in the issue/spec exists before verifying its implementation**
   — inspecting for an implementation of a requirement that was never actually
   specified produces a verdict for a requirement that doesn't exist.
   source: RTM backward-traceability verifies "the original source of
   requirements," a distinct check from forward traceability. ([Jama
   Software: Traceability Matrix guide](https://www.jamasoftware.com/requirements-management-guide/requirements-traceability/traceability-matrix/))

4. **When** two requirements in the same spec turn out to trace to the exact
   same evidence location with the same verdict reasoning (a duplicate
   requirement under different wording), **collapse them into one traceability
   entry with a note of the duplication**, rather than filing two separate
   line items — a duplicated entry inflates the record's apparent coverage
   count without adding distinct evidence. (removal) source: 29148
   "consistent" characteristic — a requirement set with two entries pointing
   at identical evidence is not internally consistent as a checkable list.
   ([Well-Architected Guide: ISO/IEC/IEEE 29148 SRS template](https://www.well-architected-guide.com/documents/iso-iec-ieee-29148-template/))

5. **When** the spec itself exists in more than one version/draft that a
   target artifact could plausibly be built against (a versioned schema, a
   revised API contract, a superseded policy revision), **name the exact
   spec version the evidence was checked against alongside the file:line
   citation**, not just "the spec" — a citation with no version pin cannot
   later distinguish "conforms to the version in force" from "conforms to a
   version already superseded," and a reader re-deriving the verdict against
   the current spec would silently check the wrong baseline.
