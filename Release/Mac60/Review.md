# Mac60 review and validation

Approved direction: native Mac sidebar and compact, flat workspaces with restrained colors. Existing TabView state and iOS branches retained. Design concept is illustrative; Store assets must be real final app screenshots.

Independent code review found two regressions, corrected before release:
- Mac result identity restored the existing partial-response warning condition.
- Request URL Return no longer sends; edited-copy requests retain explicit Send-button behavior.

Initial native QA confirmed sidebar navigation, HTTPS success, HTTP cleartext label, readable expired-certificate failure, issuer details/back navigation, request draft retention and Tools input/output retention. It found smart quote substitutions in technical input and possible Request width overflow. Mac technical editors now disable quotes/dashes/autocorrection; Request width is constrained without clipping. Added two focused Mac tests for editor traits and literal binding updates. Final native verification pending.

Source-only iOS branch comparison and iOS build passed; 3 targeted TLSDisplay/HAR tests passed. Full Mac regression passed: 165 methods / 37 suites, including both editor tests. Final iOS build also passed. Independent follow-up review found no remaining concrete blocker. Final native Light/Dark readback remains in progress.

The initial Request screenshot was later found to have a window/capture-position confound; native Fill and Left menu layouts kept all controls inside the window. The width constraints are retained as defensive layout sizing, not evidence of a reproduced clipping defect.

Final Dark functional verification passed, including literal ASCII edits, cURL import, explicit send-only behavior in ordinary and edited requests, retained drafts and system HAR share presentation. Actual Light appearance verified using a temporary Debug-only Info.plist override; source was restored before archive. The signed universal archive has no UIUserInterfaceStyle override and follows system appearance. Final exported-file roundtrip remains unverified.
