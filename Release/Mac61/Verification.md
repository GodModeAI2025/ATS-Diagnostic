# Mac61 verification

- Baseline Mac60 native export: 16 records and 3 failures exported to an actual file, then imported through the application. History increased to 32 records and 6 failures; imported provenance visible. Existing history was not deleted.
- New Transferable file regression reproduced two defects before the fix: `.har.json` suffix and missing milliseconds. Both corrected with a JSON-conforming imported HAR type and fractional ISO-8601 timestamp output.
- Final complete Mac regression: 172 tests in 38 suites passed, including actual bundled German resources. Targeted iOS regression: 32 tests in 6 suites passed. Full logs/xcresults are retained in work/.
- Additional coverage passes: malformed HAR structure, credential-bearing URL, excessive entry count, UTF-8 byte sizes, binary response content, errors, failed second-entry import with unchanged history, raw certificate values/CA assertions unchanged by UI translation.
- HAR intentionally does not recreate certificate chains or system trust results. Imported records are not a fresh network validation.
- The imported UTI declaration describes the external HAR format; it does not assert ownership of that format. No MIME tag is claimed because the app registers `.har` and JSON conformance, not generic JSON files as exclusively HAR.
- Current Mac sharing route: Share → Copy → Finder paste. A direct Save action is not supplied by the system share sheet in the tested configuration.
- Upload61 succeeded; Apple processing complete. Build61 replaced build60 and was submitted at 22:16 CET on 2026-10-27; status Warten auf Prüfung.

## Native final validation

- Normal-window native .har roundtrip: 33 → 66 records. Same file in fullscreen initially had disabled Open; .har.json control and normal-window .har selection showed this was presentation-specific, not a format/parser failure.
- Moved the SwiftUI fileImporter from GeometryReader to the stable outer NavigationStack; content types explicitly include .httpArchive. Fullscreen Open then enabled, real import 67 → 100 records, failures 13 → 19. Imported provenance shown. No existing history deleted.
- Normal/fullscreen exports are byte-identical for the same captured records. Finder menu Paste created one valid file. Automated Cmd-V produced two identical copies; this observation is not attributed solely to application code.
- Certificate UI checked in German: identity, issuer, expiry, fingerprints, CT result/log states, keys, metadata, extensions and expired-certificate explanation. Technical OIDs, identities, hashes, DNS names, URLs and external operator/log names remain unchanged.
- Final archive verifies arm64/x86_64, macOS15, existing ATS exception/local-network purpose, sandbox client/file selection entitlements; no server entitlement or appearance override.
- Native TestFlight-installed app and final public Store availability remain unverified.

Final single-instance QA: toolbar/back navigation, fullscreen import dialog reopen/cancel and export Share all work; earlier transient toolbar observation during parallel automated test-host execution did not reproduce after a clean launch. Final screenshot originals are QA/Certificates/Store-Final-Aussteller.jpg and Store-Final-Erklaerung.jpg. Final history contains 101 retained test records; no deletion was performed.

## Release outcome

Source fb36f7e pushed to origin/main. Mac 2.0.1 (61) is Im Test in Mark – Intern (only mark_zimmermann@mac.com, invited). The new certificate screenshot is second among four Store screenshots and inherited by German localization. App Store submission f3fbe14a-3727-4beb-b264-f0e39dba5b73 is Warten auf Prüfung, automatic release after approval. This is submission, not approval or public availability.
