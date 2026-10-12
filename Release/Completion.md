# ATS Diagnostic delivery requirements

The release is complete only when the combined functionality is implemented and verified, the repository is pushed, and the build is processed and available to the intended TestFlight testers.

## Connection inspection
- [x] Host and URL input; HTTP request execution; system trust evaluation
- [x] Presented/evaluated certificate chain; SHA-256 fingerprints; DER export
- [x] Negotiated TLS version/cipher, HTTP protocol, remote address and phase timings
- [ ] Complete typed X.509 decoder (initial ASN.1 fields implemented): SAN, EKU, KU, AIA, SKI/AKI, policies, public key, issuer, validity, serial
- [ ] Trust failures, hostname/expiry/weak-crypto/interception findings
- [x] Independent TLS-version support probes with negotiated-version readback
- [x] Dated root-store inclusion comparison; system CT-qualified result and embedded SCT/log decoding
- [ ] Independent alternate-platform trust policies; SCT signature/inclusion checks; revocation details
- [ ] Safari share extension on iPhone/iPad and macOS support

## Traffic capture and editing
- [x] Manual HTTP request builder and replay; cURL export
- [x] Local history, URL/method/status search, deletion and bounded body capture
- [x] cURL import; HAR import/export; NDJSON export
- [ ] PCAP capture/export
- [x] Response-type filters, logging controls, URL exclusions, aggregate statistics, favorites
- [ ] URLProtocol developer integration and shake/custom presentation hooks
- [ ] Proxy-only, full-tunnel and dual-MITM modes
- [ ] Local root CA generation, certificate setup, per-host leaf generation and MITM allowlist
- [ ] HTTP/2, WebSocket, SSE, DNS, TCP/UDP, QUIC/HTTP3 and gRPC capture
- [ ] Rewrite rules, request maps, breakpoints, scripts and hosts overrides
- [ ] Custom DNS, IPv6, SOCKS5, TCP/UDP forwarding, QUIC/ECH controls
- [ ] Throttling and storage/body/capture-domain limits
- [ ] Connection, UDP and DNS diagnostics
- [ ] Widget, Live Activity, Control Widget and quick actions

## Utilities and delivery
- [x] Base64, URL encoding, JSON formatting, SHA-256/SHA-512 and timestamps
- [ ] Other historical utility parity confirmed against tags and history
- [x] Full-chain export; PEM/CRT/DER formats
- [x] Certificate expiry reminder planning and local notification scheduling (delivery not device-verified)
- [ ] ALPN, IDNA hostnames, reverse DNS and redirect-aware per-hop TLS results
- [ ] Certificate transparency SCT/log checks, OCSP/CRL/revocation
- [ ] Alternate trust store evaluation and known compromised CA findings
- [ ] Advanced inspection parameters, reset controls, global timeout
- [ ] NSS key material export where technically available and explicitly enabled
- [ ] Language selection/localization, alternate icons and logs export
- [ ] Certificate information links and Safari web extension/handoff
- [x] Download-integrity check with streaming SHA-256 over the complete response
- [ ] Preferred cipher order, multipath and expanded content-encoding analysis
- [ ] Local privacy controls, export disclosure, privacy manifest and store metadata
- [ ] App icon, iPhone/iPad screenshots, accessibility and appearance QA
- [x] Existing App Store bundle identifier and version/build numbers verified
- [ ] Unit/integration/device tests; signed archive; upload and processing
- [x] Initial build30 TestFlight tester/group assignment and available-build readback (only mark_zimmermann@mac.com)
- [x] Push to the authorized repository (subsequent development continues)

Implemented checkboxes describe code presence, not completed runtime verification.

Historical parity additions: stream breakpoints/scripts, stream journal/replay audit, capture initiator metadata, hybrid/fail-open routing, UDP packet analysis, cURL protocol selection/multi-transfer import, regex URL exclusions, query parameter viewer, session-log export and integration notifications.

Preview build32 installation/use verified through the intended tester’s eight TestFlight screenshot reports. Build33 feedback changes and remaining limitations are recorded in Feedback-33.md.

## Current diagnostic verification

The native badssl catalog covers 73 URLs (72 linked test targets, including four defunct targets, plus the baseline). The iOS 27.0 simulator integration run completed on 2026-10-11; all 79 current unit tests passed. German explanations preserve the actual error evidence and distinguish HTTP responses, system trust, and separately verified revocation. Structured certificate issuer attributes and navigation to the next issuer certificate are implemented. See BadSSL/Validation.md for the observed matrix and browser-testing limitations. Simulator UI spot checks are preserved in Screenshots; Preview36 is processed and available in the manual owner-only group. Physical installation and QA of build36 remain unverified.

Further diagnostic improvements remain open: complete supported-cipher enumeration, key-exchange group analysis, verified vulnerability-specific probes, endpoint-specific findings across multiple server addresses, and timestamped comparisons of repeat assessments. Negotiated connection metrics alone do not establish those server-wide properties. External assessment integration would need to clearly distinguish remote results from device measurements and disclose the transfer of the target hostname.

## HTTP diagnostic parameters

Persisted idle and total HTTP timeouts, response-preview retention0–16MiB, reset to20s/30s/2MiB, and per-record applied parameter snapshots are implemented and verified. They apply to new Inspect/Requests operations. The controlled badssl reference and TLS-version probes retain their independent limits; full global probe configuration remains open. Complete hashes and byte counts survive zero or limited body previews.86 tests passed; fresh73-target native iPad regression preserved44 rejected transports/27 HTTP200/2 HTTP400 plus confirmed signed-CRL revocation. iPhone settings survive restart; iPad landscape/largest text and truthful empty-preview messaging verified. Full capture/proxy/VPN/MITM functionality remains open.

## Foreground proxy and build 37

A foreground-only loopback HTTP proxy now forwards real requests and opaque CONNECT streams. Bidirectional TCP, half-close, HTTP upgrade, bounded previews, byte counters, explicit start/stop, background stop, deferred JSON export and native client self-test are implemented. Direct HTTPS forwarding validates server certificates and reports the actual trust error immediately. This is one part of the requested proxy/tunnel scope; device-wide VPN, root CA/MITM, PCAP, protocol decoding and developer integration remain open.

95 app tests and six live HTTPS cases passed after the CONNECT completion fix. iPhone/iPad proxy UI, landscape, large text and background listener shutdown were verified in isolated simulators. Build 2.0 (37), source 8dcf579, was uploaded successfully on 2026-10-12. Processing completion and manual owner-group assignment remain unverified because the App Store Connect browser session expired. Build 36 remains the last portal-verified owner-group build. See Proxy/Validation.md and PreviewRecord-37-Pending.json.

The next capture implementation is developer URLProtocol integration, followed by tunnel/MITM functionality and broader protocol coverage. History now observes record identities rather than count, correcting equal-size eviction refresh; the targeted iPad 10+1 regression, landscape and largest-text settings checks passed. 99 unit tests passed. These changes are in archived build 38, uploaded successfully on 2026-10-12 at 00:41:01 CEST; processing and owner-group assignment remain unverified because the browser session expired; they are not in uploaded build 37. Aggregate retention budget and asynchronous persistence remain open.

## Developer SDK foundation

DeveloperSDK contains the independent ATSRecording Swift package. Its opt-in RecordingClient wraps the caller's existing URLSession data(for:) without replacing session configuration or authentication handling. Complete response data returns to the caller; the in-memory journal retains separately copied bounded previews, full successful-response hashes, original transport error domains/codes, count and encoded-byte limits, clear and JSON export. Five controlled tests and three native live HTTPS cases passed on macOS. The package compiled for iOS Simulator; iOS SDK runtime verification remains open.

This foundation does not complete automatic URLProtocol capture or historical SDK parity. Streaming, automatic capture and complete redirect/connection metrics remain open; subsequent SDK progress and activation verification are documented below. Bounded metadata-only recording/clear/omission events, revision-gap resynchronization and explicit observer cleanup are now implemented in the separate SDK. HAR export/app import is implemented for build 39 with explicit provenance, reported hashes/errors, unknown-byte/protocol handling and unavailable-body replay protection. It is not embedded in uploaded build 38. See SDK/Validation.md.

Build 39 candidate: SDK HAR interoperability and import provenance implemented; six controlled SDK tests/three live cases and 105 final App tests passed. Native iPad file-picker imports, partial POST preview/disabled replay, reported hash, certificate-error import and final grouped-hash/unknown-protocol display passed. See SDK/HAR/Validation.md. This does not complete automatic URLProtocol capture, VPN/MITM, PCAP or the remaining historical parity requirements.

Build 39 uploaded successfully at 2026-10-12 01:28:37 CEST. Processing completion and manual owner-group assignment are not verified: App Store Connect still requires sign-in. PreviewRecord-39-Pending.json preserves the exact boundary; Preview36 remains the last portal-verified group build.

SDK events: ten controlled macOS tests passed (two opt-in live test methods skipped in this run); iOS Simulator build passed. Producer/observer lifetime and bounded event queues are verified. This SDK-only change does not alter uploaded App build 39.

SDK runtime verification on iOS 27.0 now passed: ten controlled tests plus a separate targeted run of three live HTTPS cases (two test methods). Response preservation, HAR, events/observer lifecycle and default system certificate rejection are verified on the isolated iPhone Simulator. See SDK/Events/iOSRuntimeSummary.json, iOSLiveSummary.json and iOSLive.log. This does not prove physical-device behavior or finish the remaining automatic capture/tunnel/presentation requirements.

SDK transfer APIs now include Data uploads, file-backed uploads and downloads through the host URLSession. Downloads use bounded 64-KiB file reads with full hashes and independent preview limits; the multi-chunk and zero-preview cases passed. File uploads leave the source file unchanged and mark the uncaptured request body unavailable in HAR. The current controlled macOS and iOS suites pass 19 tests; two opt-in live methods were skipped. Custom activation presentation passed iPad UI QA; actual shake remains unverified with available tools. These SDK-only changes do not alter uploaded App build 39. Streaming, automatic URLProtocol capture and full historical SDK parity remain incomplete.

History persistence now performs JSON encoding and protected atomic writes in a dedicated actor. Revision checks prevent late snapshots from undoing clear/newer changes; current-revision errors alone update UI state. Two regression tests and the final full 107-method app suite passed. The first full run had a loopback Network-is-down failure, absent in the successful full rerun. Initial loading/retention remain synchronous and background flush/coalescing remain open. This change is not part of uploaded Build 39. See History/Async/Validation.md.

History background writes now coalesce pending snapshots and hold a system-granted UIKit background task until completion/expiration. The 20-imports → clear → flush → reload regression and full 108-method app suite pass. Native iPhone Simulator UI verified create/background/restart preservation and clear/restart emptiness. The empty-history overlay found during QA is now placed in normal List flow; final phone/iPad landscape/largest-text visual verification passed; empty content is scrollable without overlap. Source is not yet in uploaded Build 39. See History/Flush/Validation.md.

Build 40 (source 17d5f1c) archived successfully and uploaded on 2026-10-12 at 02:30:13 CEST. This includes asynchronous/coalesced protected history writes, system-granted background completion and the corrected empty-history layout. Native phone create/restart/clear/restart and phone/iPad landscape/largest-text QA passed; the prior 108-method suite passed. Apple processing completion, beta-note save and owner-group assignment remain unverified: the App Store Connect browser still requires sign-in. Automatic distribution stays off; intended tester is solely mark_zimmermann@mac.com. See PreviewRecord-40-Pending.json. The separate developer SDK is not embedded.

Initial history read/decode/retention now runs in the persistence actor, with a visible loading row and mutation gates that await load completion. Immediate import/clear regressions and the final full 110-method suite pass. An earlier run again encountered the intermittently failing large CONNECT test; targeted/full reruns passed and error-phase reporting was added without suppression. Native phone restart/clear QA passed, with preserved example.com response then zero requests after clear/restart; session closed. This source change is not in uploaded Build 40.

Build 41 candidate source a3bf740 is archived successfully as 2.0 (41), com.mobilebox.atsdiagnostic.preview. Native async-history preserve/restart and clear/restart QA passed. The upload process is still live and waiting for Apple's asset-description metadata completion; no successful-upload claim is made. Continue observing the existing process rather than starting another upload. Processing completion, beta-note save and owner-group assignment remain unverified; browser sign-in is still required. See PreviewRecord-41-Pending.json and Upload-41-Pending.log.

The existing Build 41 upload completed successfully on 2026-10-12 at 02:44:35 CEST (EXPORT SUCCEEDED). Apple reports the uploaded package is processing, not processing completion. PreviewRecord-41-Pending.json and Upload-41.log now record completed upload. The browser login remains unauthenticated; account identifier was entered but interaction could not advance, and opening the page in the calling chat was queued. No beta notes or group assignment were changed. Intended distribution remains solely Mark – Intern / mark_zimmermann@mac.com with automatic distribution off.

Legacy history schema compatibility is verified using a synthetic fixture encoded by the archived own Build33 model (e77e565), not today's encoder. Six targeted persistence tests pass, including old-schema load/roundtrip with preserved ID/date/body/error/certificate bytes. This test-only change does not alter uploaded Build41 and does not prove a physical TestFlight update installation. See History/Legacy33/Validation.md.

Developer SDK streaming now observes explicit URLSession.bytes consumers with bounded previews/64-KiB hash chunks, full EOF hashes and truthful partial-error counts. Four new tests and the full 23-controlled-test macOS/iOS SDK suites pass (two live methods skipped). MainActor consumption is verified. Early-break/unconsumed finalization, automatic URLProtocol capture and new native streaming TLS live checks remain open. This is SDK-only and does not alter uploaded Build41. See SDK/Streaming/Validation.md.

Streaming live TLS verification now passed on macOS and isolated iOS27 iPad: example.com HTTP200/full SHA256 and two default-system certificate rejections. The iOS targeted run passed four methods/six HTTPS executions, covering both data and streaming APIs, with no failures/skips/warnings. Recording preserves each actual returned error. Automatic capture/abandoned-consumer completion remain open; uploaded App41 is unaffected. See SDK/Streaming/Live/Validation.md.

Structured SDK streaming scope completion is implemented via withBytes and explicit finishRecording: early return/parser error/header-only consumption is recorded as incomplete, without a false full hash or invented transport failure. HAR full body size remains unknown while observed bytes are separate; optional responseComplete preserves old JSON compatibility. 27 controlled iOS tests, macOS31-method live-enabled suite and repeated iOS four-method/six-case HTTPS run pass. Low-level unfinalized consumers and automatic URLProtocol capture remain incomplete. Uploaded App41 is unchanged. Direct TestFlight URL again redirects to unauthenticated login. See SDK/Streaming/Scope/Validation.md.

App partial-response HAR integration now preserves reported completeness/observed bytes separately, forces unknown full size for incomplete responses and drops contradictory full hashes/counts. History/detail/map explain partial recordings without inventing transport failure; aggregate size is unknown when any response size is unknown. Actual SDK fixture generation, three new interop tests, full114-method suite and native iPhone Files-Picker UI verification passed. Controlled echo endpoints now remain open until proxy terminal capture, preserving strict payload/half-close assertions. Source not yet in uploaded App41. See SDK/PartialResponse/Validation.md.

Build42 (source49ea613) archived and uploaded successfully on 2026-10-12 at03:55:54CEST. This includes truthful partial-response import/provenance, unknown full-size presentation in overview/detail/map and preserved replay semantics for complete requests. Full114-method suite and native iPhone Files-Picker QA passed. Upload reports processing started; processing completion, beta-note save and owner-group assignment are not verified. Only intended tester remains mark_zimmermann@mac.com in manual Mark–Intern; automatic distribution off. Separate SDK is not embedded. See PreviewRecord-42-Pending.json and Upload-42.log.
