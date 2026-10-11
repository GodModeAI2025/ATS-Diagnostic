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

Preview build 2.0 (32), source a37b2c4: signed archive and upload succeeded at 20:05 CEST. Apple reports package processing. New App Store Connect ID 6821686996 and manual internal group a1bcebc2-c662-4040-9ffc-f9c3f8f7898f created; only mark_zimmermann@mac.com selected as tester. Availability and installation remain pending readback.

Preview build32 completion readback: Im Test; one manual internal group, one tester mark_zimmermann@mac.com, invited at 20:10 CEST. Test notes saved. Screenshot TestFlight-Preview32.jpg. Xcode device discovery returned no physical devices, so iPhone TestFlight installation is awaiting the user's actual-device check. Full combined functionality remains unfinished.

Build33 feedback release verification: final source passes 61/61 tests via Xcode MCP, including final-response URL capture in the controlled streaming fixture. Native simulator QA passed compact Requests, EnBW200/h2/TLS1.3/three certificates, system CT qualification plus three embedded SCTs (example.com two), root-store membership, metadata/fingerprints, expandable connection map, grouped headers and CSP directives, dark/large text, iPad landscape two-pane requests/response and accessibility one-column Send reachability. The data-license sheet remained visible through two no-action captures and closed with Done. Fingerprints use four-character groups to prevent native presentation hyphens; shares retain raw digest values. Probe root source Added during system trust evaluation was verified; leaf source Sent by server was not separately UI-tested. All device-interaction sessions closed. The quick scanner's one Branch match is the app's own SwiftUI TreeBranch type, not an external SDK.

Build32 physical installation/use is now established by eight TestFlight screenshot reports from mark_zimmermann@mac.com on iPhone17 Pro Max / iOS27.2. This does not constitute physical-device QA of build33. Preview crash feedback readback: no reports. Full historical parity remains unfinished.

Preview build33, source e77e565d9886f23f12b37873af4818b512a26bb3: signed archive succeeded, binary bundle/version/resource readback passed; upload completed21:19CEST. Apple processed build c5af7c7a-3279-4bfe-8ab9-4825ce7068a9. Im Test verified in manual Mark – Intern group with exactly mark_zimmermann@mac.com; test notes saved. Portal tester state explicitly confirms build32 installed20:15CEST on iPhone17 Pro Max/iOS27.2. Build33 physical installation remains unverified. Screenshots TestFlight-Preview33.jpg and TestFlight-Preview33-Tester.jpg.

Preview34 diagnostic verification: source98ebdce, 79 current unit tests passed without failures. Native iOS27.0 simulator integration executed73 badssl URLs with system trust and ATS retained:44 transport rejections,27 HTTP200 responses,2 client-certificate HTTP400 responses. revoked.badssl.com default HTTP200 is separately qualified by a confirmed, current, appropriately scoped and cryptographically verified issuer CRL. Full raw records, German report and test-scope notes are in BadSSL/. Xcode signed archive used CURRENT_PROJECT_VERSION=34 override; archived Info.plist confirms com.mobilebox.atsdiagnostic.preview / 2.0(34), displayName ATS Diagnostic and bundled73-entry catalog. Upload succeeded22:33CEST; Apple processed e332a750-e134-44c5-8839-f37a95a1bac3. Notes saved; Im Test read back in manual Mark–Intern with exactly mark_zimmermann@mac.com. No physical-device installation of34 is claimed. Live portal now confirms33 installed21:35CEST on iPhone17ProMax/iOS27.2. Full historical functionality remains incomplete.

Simulator UI QA verified German expiry/hostname/revocation/client-certificate explanations, technical evidence, ambiguous10000-SAN TLS parameter errors, issuer C/O/CN and next-issuer navigation, plus iPad landscape/dark largest accessibility error layouts. HTTP catalog ATS blocking observed; HTTP detail and iPad issuer detail were not opened. The review identified hidden numeric HTTP status on error result pages; build35 corrects it. Follow-up own iPhone simulator confirms HTTP-Status200 alongside the separate revoked finding; screenshot BadSSL-HTTP-Status. Client400 UI was not repeated after this shared-row fix. All interaction sessions closed/settings restored. Build35 source b5757ec signed/archive bundle/build/catalog verified and upload completed22:46CEST; backend code and79-test unit suite unchanged from34.

Preview35 final portal readback: processed, notes saved, Im Test in Mark–Intern with one existing tester mark_zimmermann@mac.com. No automatic distribution change. Screenshot TestFlight-Preview35.jpg. Physical build35 installation remains unverified.

Preview36 parameters:86 unit tests via Xcode MCP passed,0 failures. Tests cover finite/bounded limits, independently shorter total deadline, historical record decoding, actual URLRequest/session configuration, and complete3MiB hashes with64-byte or zero previews. Fresh native badssl integration on own iPad/iOS27.0 executed73 URLs; raw records/report are in BadSSL/Options. iPhone UI verified saved zero-preview through restart, actual example.com HTTP200/577bytes/SHA256, applied20s/30s/zero retention, standard reset and single keyboard Done. iPad landscape/largest accessibility layout passed. Final response-body message distinguishes received data from retained preview and shows actual limit; no additional network request was made for that last UI check. All sessions closed/settings restored. Signed reviewed archive validates Preview bundle/2.0(36)/catalog; source f0fd327; upload completed23:26CEST. Processing/assignment readback follows.

Preview36 final portal readback: notes saved, Im Test in existing manual Mark–Intern group, exactly mark_zimmermann@mac.com. Build7ab28820-af24-4d05-a96a-24ab0554913b. Screenshots TestFlight-Preview36.jpg and TestFlight-Preview36-Tester.jpg. Tester still shows33 physically installed;36 installation remains unverified.
