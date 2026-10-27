# Transport configuration and release checks

- Original signed Store archive 2.0 (55) and new signed archive 2.0.1 (56): NSAppTransportSecurity contains exactly NSAllowsArbitraryLoads=true; local-network purpose string present.
- No fine-grained global ATS key overrides that exception. No unnecessary VPN, multicast or background-mode capabilities were added. Direct user-selected TCP/HTTP/TLS requests do not need a Network Extension entitlement. Local-network access remains subject to user permission.
- Independent TLS 1.0/1.1/1.2/1.3 probes configure explicit protocol bounds and preserve system trust validation/errors. The OS and server still determine which algorithms are supported. An ATS exception cannot restore removed cryptography.
- New regression test checks the actual app-bundle plist, effective ATS exception, local-network usage description and absence of background modes.
- Full suite: 158 tests passed, zero failures/skips on isolated iOS 27.2 simulator. Native QA separately tests HTTP success and expired HTTPS rejection; screenshots and report are under Screenshots/.
- Build/archive succeeded. Archive uses development signing before export (get-task-allow=true); App Store export must re-sign for distribution. Do not treat archive signing as uploaded distribution signing.
- Initial upload failed with Failed to Use Accounts. After Xcode account sign-in, retry succeeded on 2026-10-27 (Upload-Succeeded.log). Apple processed build 56; TestFlight shows Im Test for Mark – Intern, with only mark_zimmermann@mac.com invited. Physical installation is not verified. All 12 current screenshots were subsequently uploaded and version 2.0.1 (56) submitted on 2026-10-27. Apple confirmed Warten auf Prüfung, submission dbbfb2f6-65af-477a-934a-dcbe621ef7e0. This is not approval or public release.

Apple references verified 2026-10-27:
- https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking
- https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers
- https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
