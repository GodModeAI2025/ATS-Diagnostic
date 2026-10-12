# Individual connection metrics

Native URLSessionTaskMetrics now retain each transport transaction, including redirects, rather than displaying only the final connection. The record detail links to a native list with per-step URL, HTTP status, negotiated protocol/TLS/cipher, reused/proxy flags and available phase durations. Unknown timings remain unknown; overlapping connect/TLS phases are not summed. Certificate-chain trust is not claimed independently for intermediate destinations.

HAR export/import preserves the same taskMetrics schema used by ATSRecording. Imported snapshots remain reported evidence. Transactions are bounded to 128 with their reported total retained; inconsistent partial imports are marked truncated. Invalid overall metrics are dropped without discarding otherwise valid HAR entries.

Validation: existing 128 app test methods passed on the isolated iPad simulator. Five new interop tests passed: HAR round-trip, unknown phases, negative duration rejection, transaction cap, malformed-metrics isolation, plus interval assertions. See InteropTests.json and InteropTests.log.

Store version 2.0 (50) remains submitted and is not replaced by this development change. This extension is not yet uploaded to TestFlight.

Native iPhone simulator UI verification passed: enbw.com HTTP 301 → www.enbw.com HTTP 200, two transactions, h2/TLS 1.3, readable phase timings and reused connection indicator. expired.badssl.com remains rejected with a German certificate explanation and next step. Screenshots and accessibility captures are in Release/Screenshots/Connection-Metrics-*. The device session was closed.
