# ATS Diagnostic delivery requirements

The release is complete only when the combined functionality is implemented and verified, the repository is pushed, and the build is processed and available to the intended TestFlight testers.

## Connection inspection
- [x] Host and URL input; HTTP request execution; system trust evaluation
- [x] Presented/evaluated certificate chain; SHA-256 fingerprints; DER export
- [x] Negotiated TLS version/cipher, HTTP protocol, remote address and phase timings
- [ ] Complete typed X.509 decoder (initial ASN.1 fields implemented): SAN, EKU, KU, AIA, SKI/AKI, policies, public key, issuer, validity, serial
- [ ] Trust failures, hostname/expiry/weak-crypto/interception findings
- [x] Independent TLS-version support probes with negotiated-version readback
- [ ] Alternate trust stores; CT/revocation details
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
