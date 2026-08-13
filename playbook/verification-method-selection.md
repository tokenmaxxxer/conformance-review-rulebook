---
axis: verification-method-selection
rule_count_floor: 3
---

# Verification method selection

Picking HOW a requirement gets checked — inspection, analysis, demonstration,
or test — before picking a verdict. Wrong method choice produces a verdict
that looks rigorous but didn't actually check the claim.

## Rules

1. **When** the requirement concerns a structural/static property of the
   artifact (a field exists, a schema shape, a file is present at a path),
   **use Inspection** (read/compare against the spec) rather than running the
   code — inspection is defined for exactly this "what is required vs. what is
   present" comparison and is cheaper and more reliable here than execution.
   source: ISO/IEC/IEEE 29148 verification-method taxonomy. ([IEEE SA:
   29148-2018](https://standards.ieee.org/standard/29148-2018.html))

2. **When** the requirement concerns behavior under conditions the review
   session cannot realistically reproduce (load, timing, a production-only
   integration), **use Analysis** (trace the code path / reason from a model)
   instead of asserting Present from a demonstration that only exercised the
   happy path — a demonstration under artificial conditions does not establish
   the requirement under the conditions actually named. source: 29148 defines
   Analysis as the method for cases "testing to realistic conditions cannot be
   achieved or is not cost-effective." ([IEEE SA: 29148-2018](https://standards.ieee.org/standard/29148-2018.html))

3. **When** the requirement is a qualitative functional claim ("the form
   submits and shows a confirmation"), **use Demonstration** — exercise the
   actual flow with representative stimuli rather than reading the code and
   inferring behavior; code that looks correct can still fail to run. source:
   29148 Demonstration = "qualitative exhibition of functional performance...
   with system stimuli...to show system or system element response is
   suitable." ([IEEE SA: 29148-2018](https://standards.ieee.org/standard/29148-2018.html))

4. **When** a requirement has an executable test already in the repo that
   claims to cover it, **do not re-derive a fresh verification method** —
   reuse the existing test as the Test-method evidence and cite its run
   output; re-deriving a parallel manual check for something already
   test-covered duplicates effort without raising confidence. (removal)
   source: 29148's four-method taxonomy treats Test as a first-class method on
   par with the other three — an existing automated Test result is not
   downgraded to Inspection merely because a human is doing the review.
   ([IEEE SA: 29148-2018](https://standards.ieee.org/standard/29148-2018.html))

5. **When** a requirement already has a recorded, replayable interaction
   fixture that both the requesting and the satisfying side of the
   requirement can be checked against (a captured request/response pair, a
   golden snapshot, a recorded message exchange), **prefer replaying that
   fixture over re-reading prose documentation to judge conformance** — a
   replay either matches or it doesn't, while a prose comparison depends on
   the reviewer's own interpretation of ambiguous wording. Treat a passing
   replay as Test-method evidence per rule 4, not as a fresh Inspection.
