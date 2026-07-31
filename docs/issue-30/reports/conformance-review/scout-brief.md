---
subject: issue-30
role: review
loop_state: scoped
---

# Scout brief: conformance-review methodology (issue #30)

Live web search was performed this session (see Sources). Search results
were secondary-source summaries (auditor-training sites, standards
bodies' own public pages, GitHub/arXiv) rather than the primary ISO/IEC
17007 or IETF RFC 6982 text, which paywalled/archival sources kept out of
reach of search — flagged as an **assumption** below where it applies.
Everything else in this brief is grounded in a fetched result, not recall.

## Must-be (non-negotiable across every source surveyed)

- **Requirement-by-requirement, not holistic.** Every conformance/audit
  method surveyed (ISO/IEC 17007 conformance test suites, W3C test
  suites, IETF interoperability reports, ISO 19011 audit findings, IIA
  Standards) decomposes the spec into discrete checkable requirements and
  renders one verdict per requirement — never a single pass/fail on "the
  whole thing."
- **Evidence-based verdicts.** ISO 19011's audit principle "evidence-based
  approach" and IIA's Standard 2310 ("Identifying Information") both
  require a verifiable basis for every finding — an assertion without a
  traceable evidence pointer is not a finding.
- **Independence/objectivity of the reviewer from the built artifact.**
  ISO 19011 principle of independence and IIA's organizational-
  independence requirement both structurally separate the auditor from
  the work being audited — mirrors this role's existing "no builder
  intent" isolation.
- **A closed, named verdict vocabulary**, not free text. W3C/IETF
  conformance suites use pass/fail/not-applicable; this repo already uses
  a five-value vocabulary (Present/Surface/Absent/Incorrect/
  Unverifiable) that is a strict superset (distinguishes "can't tell"
  from "fails," which plain pass/fail conflates).

## Performance axes (what distinguishes a strong method from a weak one)

- **Traceability**: can every verdict be traced back to (a) the exact
  spec clause/requirement id and (b) the exact evidence location? ISO/IEC
  conformance suites and traceability-matrix practice both grade this
  explicitly; ungraded prose review scores worst here.
- **Sampling discipline when full coverage is infeasible**: AICPA/ISO
  19011-adjacent audit sampling names confidence level, expected/
  tolerable deviation rate as first-class, recorded inputs — not an
  implicit "I looked at some of it."
- **Reproducibility across reviewers**: deterministic table-lookup
  severity (Microsoft bug bar, Chromium bands) reproduces across
  reviewers; averaged subjective scoring (DREAD) does not — this axis was
  already resolved in this repo's `severity-classification` skill.

## Adopt / skip patterns

- **Adopt**: requirement-by-requirement traceability with mandatory
  evidence pointer (ISO/IEC conformance testing, OWASP finding template,
  W3C/IETF requirement-keyed pass/fail/N-A convention) — already the
  shape of `finding-record`; issue #30's job is to make the *methodology
  basis* explicit in a proposal, not to redesign the artifact.
- **Adopt**: ISO 19011 evidence-based + independence principles as the
  explicit justification for "no builder intent" and "refuse verdict
  without evidence pointer," already enforced but not previously
  attributed to a named audit standard.
- **Skip**: ISO/IEC 17007-style formal certification/registration
  machinery (accredited test labs, certification marks) — out of scope;
  this role produces a review record, not a conformance certificate.
- **Skip**: full statistical audit sampling (AICPA confidence-level
  math) — noted as a real practice but not adopted wholesale; a lighter
  "sampling derivation" note (already implied by this role's directive:
  "extracted requirement list (or sampling derivation)") is sufficient
  for this role's scale.

## Gap line

The existing `finding-record`/`severity-classification` skills already
implement most of the *shape* this survey recommends, but the *why* —
which named external methodology each design choice tracks — was
previously undocumented. That gap is what the phase-1 proposal
(`docs/issue-30/proposals/conformance-methodology.md`) closes: it makes
explicit that this role's existing design is a converged instance of
ISO/IEC conformance testing + ISO 19011/IIA audit practice, not an
independent invention, and formalizes the phase-1 proposal norms
alongside it.

## Sources

- [An Introductory Guide to ISO 19011 — SafetyCulture](https://safetyculture.com/topics/iso-19011)
- [ISO 19011: A Comprehensive Guide to Quality Management Auditing — Certainty Software](https://www.certaintysoftware.com/iso-19011/)
- [Understanding ISO 19011: the core guidelines for auditing management systems — CertPro](https://certpro.com/understanding-iso-19011-auditing-management-system/)
- [What is this thing called Conformance? — NIST](https://nist.gov/itl/ssd/information-systems-group/what-thing-called-conformance)
- [Test Development FAQ — W3C QA WG](https://www.w3.org/QA/WG/2005/01/test-faq)
- [QA Warrior Guide — W3C](https://www.w3.org/QA/Test/TestGuide.html)
- [Understanding Conformance (WCAG 2.1) — W3C WAI](https://www.w3.org/WAI/WCAG21/Understanding/conformance)
- [International Professional Practices Framework (IPPF) — The IIA](https://www.theiia.org/en/standards/international-professional-practices-framework/)
- [2024 Global Internal Audit Standards — The IIA](https://www.theiia.org/en/standards/2024-standards/global-internal-audit-standards/)
- [Requirements Traceability Matrix — Tutorialspoint](https://www.tutorialspoint.com/software_testing_dictionary/requirements_traceability_matrix.htm)
- [Requirements Traceability Matrix (RTM) Best Practices — ComplianceQuest](https://www.compliancequest.com/cq-guide/traceability-matrix-best-practices/)
- This repo's own prior research, already load-bearing for the existing
  `finding-record`/`severity-classification` skills:
  `docs/reports/research/2026-07-27-role-practice/review.md`,
  `docs/reports/research/2026-07-27-role-interaction/review.md`.

**Assumption flagged**: primary-source text for ISO/IEC 17007
(conformance assessment vocabulary) and a specific IETF interoperability-
report RFC (e.g. RFC 6982's format) was not reachable via web search in
this session — the claims attributed to those two above are carried from
this plugin's own prior research docs and general domain familiarity, not
a freshly fetched primary source, and are marked as such rather than
cited as verified.
