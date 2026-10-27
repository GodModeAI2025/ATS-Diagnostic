# ATS Diagnostic for macOS

Requested on 2026-10-27: add macOS to the existing ATS Diagnostic bundle and Store record. The prior iOS release task is closed; this does not reopen the historical feature-parity backlog.

## Implementation

- Reuse the existing SwiftUI/iPad app through Mac Catalyst, with bundle `com.mobilebox.atsdiagnostic` and App Store record `1297164068`.
- Enable Catalyst on the original app and its unit tests. Keep the existing preview app separate and unchanged in scope. Build 58 / version 2.0.1.
- Minimum macOS 15.0. Shared responsive layouts already use available window width. Verify them with native pointer/keyboard interaction and resizing.
- Production Mac entitlements: App Sandbox, outgoing network connections and user-selected read/write files. Preserve diagnostic ATS exceptions, local-network explanation and HTTPS trust validation. No proxy/server/VPN capability.
- The test host alone may listen on loopback for existing network fixtures, using `Tests/MacTestHost.entitlements` as an explicit test-command override. Never use that file for archive/export.
- Verify native Mac tests, live network success/failure, file interaction, signed archive and actual Store screenshots. Upload the macOS build separately, then assign only the existing owner test group and prepare the macOS Store version.

## Why Catalyst

The current UI and diagnostic logic compile on Catalyst. A separate AppKit implementation would duplicate the same functionality. Running the iPad binary on Apple Silicon would not provide the requested macOS platform release. Catalyst preserves one codebase while producing a separately signed Mac app under the same bundle.

## Release boundaries

iOS 2.0.1 (56) was observed as **Bereit für Vertrieb** in App Store Connect during this work. Do not replace that iOS build. Record each Mac release stage separately; an uploaded archive alone does not establish TestFlight availability or approval.
