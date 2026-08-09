---
proposal: docs/issue-51/proposals/2026-08-09-adopt-test-env-resolution.md
---

# Hunt record — adopt-test-env-resolution

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the planned SKIP-preamble would permanently silence the self-contained `missing-core -> deny` regression case in exactly the CI environments (no real core reachable) it's meant to run in
Kind: design-error
Seed: docs/issue-51/proposals/2026-08-09-adopt-test-env-resolution.md (plan step 2, third bullet: "On exit 75: ... exit 75 immediately -- before any case runs, including missing-core, since that case's own point ... is only a meaningful regression check when core reachability is otherwise the resolved, working baseline")
cap_seconds: 60
tier: default (docs-only)
diff_stat_lines: N/A (proposal not yet built; no diff, plan text only)
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:01:00Z

### Reproduce
```
cd /home/jwjung/.tokenmaxxxer/work/conformance-review-rulebook-issue-51-implementation
ls -d review-severity/tests/../../core   # confirms no sibling core on this checkout
env -u CLAUDE_PLUGIN_ROOT_CORE bash review-severity/tests/severity-gate-test.sh 2>&1 | grep missing-core
```

### Observed
`ok     missing-core                       deny` -- the case runs and passes today, with
no `CLAUDE_PLUGIN_ROOT_CORE` set and no `../../core` sibling present. It works because
the case sets its own bogus core path inline
(`CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core"` at review-severity/tests/severity-gate-test.sh:114)
and asserts the gate's guarded-source denies -- it is entirely self-contained and has
never needed a real, reachable core to execute or to be meaningful. The same pattern
(`grep -rn missing-core review-*/tests/*.sh`) repeats in all four gate-test scripts the
proposal plans to modify.

The proposal's plan reasons that this case is only "meaningful" when "core reachability
is otherwise the resolved, working baseline" and therefore should be skipped along with
everything else on exit-75. That premise is false for this specific case (as shown by
running it in exactly the no-core environment above), and the plan's own preamble
placement -- resolver check first, exiting 75 before the case list runs at all -- would
apply to this case regardless. In the common CI environment this proposal is designed
for (no real core reachable, which is the target state per the proposal's own "How
you'll know it worked" section), the whole script would now short-circuit at the
resolver and exit 75, so `missing-core` would never execute again. A future regression
that makes the gate ALLOW instead of DENY when core is missing/unreachable would go
completely unflagged: CI would print SKIP and exit 0, identical to today's clean run.

### Expected
The `missing-core -> deny` case (and its equivalents in the other three gate-test
scripts) should keep running unconditionally, independent of the outer
CLAUDE_PLUGIN_ROOT_CORE resolution outcome, since it self-injects its own core-absent
condition and does not depend on a real core checkout being reachable. Placing it after
the resolver's exit-75 short-circuit silently disables it in the exact environments
where the fail-closed contract most needs continuous verification.
