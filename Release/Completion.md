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
