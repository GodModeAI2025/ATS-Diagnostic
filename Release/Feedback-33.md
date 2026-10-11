# Build 33 — TestFlight feedback fixes

Eight screenshot reports for Preview 2.0 (32) were read on 11 October 2026, together with the supplied certificate-detail photo. The reports came from the intended tester on iPhone 17 Pro Max / iOS 27.2. This establishes actual installation and use of the new Preview identity for build 32. The Preview crash-feedback page had no crash reports at readback.

The request form now collapses optional headers, body and checksum controls. Native grouped backgrounds and compact metrics improve the reading order. Response text is a bounded preview with a separate full-text page, preventing large bodies from dominating the connection detail screen.

A connection map exposes the relationship between endpoint, TLS chain, CT, HTTP headers and body. Headers have separate rows, purpose categories, search and optional explanations. CSP and Permissions-Policy are split into expandable directives while retaining the complete raw value.

Certificate detail pages expose SHA-1 and SHA-256 fingerprints, key identifiers, serial number, human-readable algorithms, X.509 version, source, findings and exports. X.509 v3 is presented as v3 rather than the encoded zero-based value 2.

Root-store inclusion compares exact DER SHA-256 fingerprints with separate TLS root-list snapshots for Apple, Google Chrome, Microsoft and Mozilla. Published constraints and snapshot date remain visible. This is membership information, not emulation of each platform's full certificate verifier. The bundled snapshots contain 122 / 101 / 181 / 121 entries respectively. CCADB data terms are bundled and accessible in the app.

Certificate Transparency displays the public Security framework's CT-qualified result separately from parsed embedded SCTs. Log identification uses the dated Google directory. An absent system result does not assert CT failure. Standalone SCT signature checks and Merkle inclusion proofs remain outstanding.

URLSession certificates are labeled as members of the system-evaluated chain, without claiming that every certificate was sent by the server. TLS probes use public peer-chain metadata to distinguish sent certificates from certificates added during system evaluation.

Validation: 61 Swift Testing checks passed via Xcode MCP, including SCT framing failures, independent root snapshots, old-certificate decoding, full-response integrity, safe cURL import, HAR and HTTP proxy-parser foundations. The proxy parser has no live capture UI or listener in this build. The App Store quick scanner's single Branch result was reviewed: it matches the app's own SwiftUI TreeBranch type; there is no Branch SDK, tracking SDK or third-party dependency.

This Preview remains an incremental delivery. Full historical feature parity, live proxy/tunnel/MITM capture, independent alternate-platform trust evaluation and revocation are still outstanding.

Release status: signed archive/upload succeeded; Preview 2.0(33) processed and Im Test, assigned solely to mark_zimmermann@mac.com through the manual Mark – Intern group. Build notes saved. Portal separately confirms installed build32; physical installation of build33 remains unverified.
