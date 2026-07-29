---
proposal: docs/issue-22/proposals/coding.md
---

# Hunt record — wake-routing-scope

## after-proposal — stance 1: file-scope completeness check for WAKES-ON/wake-routing mentions

Verdict: NO FINDING
Seed: docs/issue-22/proposals/coding.md claims review/hooks/directive.sh lines 61-68 is the only in-scope file; probe for missed case/phrasing variants (wake on, wakes-on, wake_on, trigger list, summon) elsewhere in the repo.

### Reproduce
grep -rniE "wakes?[-_]?on|wake[-_ ]rout|trigger list|summon" . --include="*" 2>/dev/null | grep -v '\.git/'

### Observed
Matches only in review/hooks/directive.sh:61, plus docs/issue-22/proposals/coding.md, docs/issue-22/reports/coding/survey.md, and docs/proposals/2026-07-26-contract-v2-conformance.md (the excluded historical doc). No other rulebook/hook/spec/handbook file matches under any case or phrasing variant tried.

### Expected
N/A — claim holds.
