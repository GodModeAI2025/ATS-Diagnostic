# Build 61 VPN clarification audit — 2026-10-28

Apple rejected macOS 2.0.1 (61) under 2.1.0 App Completeness with an automated request for VPN-functionality clarification. No crash, reproduction steps or required replacement binary were specified in the message.

The exact archived application at work/ATSDiagnostic-Mac61-Final.xcarchive was inspected:

- CFBundleVersion 61.
- codesign --verify --deep --strict: valid on disk and designated requirement satisfied.
- Signed entitlements: com.apple.security.app-sandbox, com.apple.security.network.client, com.apple.security.files.user-selected.read-write (all true).
- No embedded .appex and no NetworkExtension framework link in either architecture.
- No NetworkExtension imports or NEVPN/NETunnel/NEPacket APIs in app source. A substring VPN in the bundled CT-log public key is data, not functionality.
- Unused historical proxy source remains in the checkout; no ProxyMonitor creation from the app, and no matching LocalHTTPProxy/ProxyMonitor symbols in the inspected arm64 release binary. The response claims no VPN functionality, not absence of every historical proxy source file.
- Diagnostic requests and TLS probes target user-selected endpoints. History persistence is local. DNS resolution and certificate/revocation network fetches are acknowledged explicitly in the reply.

An initial sandboxed codesign read returned an invalid-entitlements warning; the authorized unsandboxed read and strict verification succeeded and returned the three entitlements above.
