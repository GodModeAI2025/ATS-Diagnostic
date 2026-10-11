# Validation evidence

2026-10-11:
- Xcode 27.0 (27A266a), Xcode MCP connected, native project built successfully before HAR integration.
- Initial four Swift Testing checks passed: HTTPS default, URL credentials rejection, non-HTTP schemes rejection, cURL shell quoting.
- Simulator HTTPS inspection returned 200, h2, TLS 0x0304, cipher 0x1302, timing phases and four certificates.
- Registered App Store Connect record verified: ATS Diagnostic / 1297164068 / com.mobilebox.atsdiagnostic, existing 2.0 draft, manual release.
- Latest visible historical TestFlight build: 1.2.0 (29), uploaded 2018-09-08, expired. New build number selected: 30.

Updated decoder/HAR test suite: 10 passed, 0 failed via Xcode MCP. App Store quick scan: 11 files, no raw findings.

Pending: full UI QA, full functional parity, signed archive, upload, processing and tester availability. No TestFlight completion is claimed.

Additional checks: 22 tests passed via Xcode MCP, including cURL import, recording exclusions, response categorization, key usage and ASN.1 time boundaries. Simulator keyboard Done button and Base64 output verified. Own opaque 1024px app icon visually verified.

Build 2.0 (30): signed archive succeeded; upload initially rejected for missing iPad upside-down orientation, fixed and rearchived. Corrected export/upload succeeded at 2026-10-11 19:00 CEST. Apple reported Uploaded package is processing. Tester availability not yet verified. Archive source commit 938f7f7.

Extended simulator QA: cURL import fields, favorite/filter statistics, recording-off immediate display, typed certificate details and sorted JSON formatting verified. No crashes. Recording-off persistence after restart and HAR UI remain unverified. Independent TLS probes compile; runtime verification pending, not included in uploaded build 30.

Apple processing completed. Build30 manually assigned to Mark – Intern, one existing Mark account. Existing automatic App Store Connect Users group also receives build30 and contains another tester; owner-only restriction pending explicit approval to remove that tester from this app-specific group.

TestFlight Build 2.0 (30): Im Test verified in group builds. Owner-only restriction completed after explicit user confirmation: both associated internal groups now contain only mark_zimmermann@mac.com; no external groups. Group30 screenshot saved. Full parity remains unfinished.

Latest visual verification: small vector illustrations render; standard iPad landscape Home and Details use balanced two-pane layouts. Home text no longer truncates. In-place largest accessibility-size transition now uses a separate vertical stack with no retained card overlay. Screenshots saved. 24 tests passed before final layout-only corrections; Xcode MCP build passed after corrections.

User reports Build30 cannot install through TestFlight despite Im Test. Store record has 0 available regions. Separate com.mobilebox.atsdiagnostic.preview test identity expressly authorized, registered and awaiting App Store Connect creation. Original App Store availability remains unchanged.

Streaming integrity verification: 29 tests passed, including a controlled 3 MiB response proving checksum covers all bytes beyond the 2 MiB preview limit. Wide Request/Tools/History layouts added; build verification passed, final screenshots pending. Preview App ID registered and present in fresh App Store Connect app dialog. Administrative access choice awaits explicit authorization after automatic approval rejection.

Final wide-workspace simulator QA passed: clean GET to example.com returned 200/TLS1.3/four certificates; History updated statistics; Tools formatted sorted JSON. Requests, History and Tools showed no standard-landscape clipping or overlap. All sessions closed.

Certificate format exports added after frozen Preview build31: DER/CRT binary and PEM single/complete chain. 32 tests passed via Xcode MCP, including PEM byte roundtrip, chain order and subject filename sanitization. These additions are not yet in an uploaded build.

Local expiry reminder planning: 37 tests passed. Isolated simulator UI verified certificate subject/expiry, date picker, include-subject default off, and DER/PEM/CRT/chain export controls. No reminder was scheduled in QA, so notification delivery remains unverified. User explicitly freed all pending actions; App Store Connect Preview record created: 6821686996.
