# Validation evidence

2026-10-11:
- Xcode 27.0 (27A266a), Xcode MCP connected, native project built successfully before HAR integration.
- Initial four Swift Testing checks passed: HTTPS default, URL credentials rejection, non-HTTP schemes rejection, cURL shell quoting.
- Simulator HTTPS inspection returned 200, h2, TLS 0x0304, cipher 0x1302, timing phases and four certificates.
- Registered App Store Connect record verified: ATS Diagnostic / 1297164068 / com.mobilebox.atsdiagnostic, existing 2.0 draft, manual release.
- Latest visible historical TestFlight build: 1.2.0 (29), uploaded 2018-09-08, expired. New build number selected: 30.

Updated decoder/HAR test suite: 10 passed, 0 failed via Xcode MCP. App Store quick scan: 11 files, no raw findings.

Pending: full UI QA, full functional parity, signed archive, upload, processing and tester availability. No TestFlight completion is claimed.
