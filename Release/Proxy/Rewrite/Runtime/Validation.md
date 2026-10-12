# Proxy runtime rule wiring and fixture shutdown

Configured rules are now passed as an immutable snapshot to each relay. The first exact-URL match wins. A successful rule retains originalTarget and rewriteRuleApplied alongside the observed forwarded target. Rewritten headers are bounded before connecting; header-only serialization avoids an extra full-body copy. Default empty rules preserve existing behavior. UI rule configuration remains open.

Native loopback tests verify actual mapped target/PUT/header/body at an owned fixture, cross-origin credential removal, first-rule precedence and original-target capture. Oversized rewritten headers return422 before an origin connection. All27 affected test methods passed; the complete144-method app suite also passed with zero failures/skips.

Earlier affected-suite runs hit NWError50 in the existing large CONNECT case, including a run with serialized tests. An initially incorrect single-test selector executed zero tests and was discarded as evidence. The corrected isolated selector executed one successful test. Fixture teardown previously queued proxy shutdown and immediately advanced. Tests now drain shutdown synchronously and run their network fixtures serially; subsequent affected/full suites passed. Original failure handling and CONNECT completion assertions remain strict. This establishes successful corrected runs, not a guarantee that every OS/network failure is eliminated.

TestFlight53 does not contain this subsequent runtime wiring/shutdown change. Store50 remains submitted and unchanged.
