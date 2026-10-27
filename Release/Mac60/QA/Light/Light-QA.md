# Mac60 native Light QA — 2026-10-27

Running app supplied by root: PID 21914, Debug Mac Catalyst, com.mobilebox.atsdiagnostic. Root temporarily forced Light only in the Debug binary and restored source Info.plist. This QA agent made no code, build, release, global appearance, or Store changes.

## Final unmodified native captures

All four images are original CUA JPEG bytes, verified with sips: 2048 × 1538. Native Window > Move & Resize > Return to Previous Size restored this size. No crop, scaling, compositing, or pixel edits were performed.

- 01-Inspect-HTTPS.jpg: https://example.com, actual HTTP 200, TLS 1.3, four certificates, 0.634 s; certificate chain and timing columns visible.
- 02-Certificate-Issuer.jpg: example.com identity, UTC validity, issuer country US, organisation SSL Corporation, name Cloudflare TLS Issuing ECC CA 3; back navigation worked.
- 03-Requests-GET.jpg: explicit Send produced actual GET response HTTP 200/TLS 1.3/four certificates/0.130 s at 20:27:10. Response body and complete-response control visible.
- 04-Tools-Result.jpg: typed ATS Diagnostic, Base64 result QVRTIERpYWdub3N0aWM= matches expected output.

Each has a matching -AX.txt evidence file. 00-Initial.jpg and Size-Restore.jpg retain initial appearance/size evidence.

## Visual assessment

Actual Light appearance confirmed by native screenshots. Sidebar selection, restrained teal actions, flat inspection sections, four evenly spaced metrics, and two-column timing/certificate layout are readable. Requests and Tools remain inside the restored window bounds. Empty input/output space is appropriate for variable payloads. The certificate detail retains a mobile-style grouped form and mixed German/English labels; this is a known remaining visual/localisation inconsistency, not a new functional failure.

The purple macOS capture indicator remains top-left and a pointer halo remains in original screenshots. A later capture did not remove them. The pointer was moved with an actual native click into empty lower-left sidebar before final captures so it covers no product content. These OS overlays have not been edited away.

## Scope and earlier final-source checks

See ../Final/Dark-Verification.md and ../QA-Pass1.md for native HTTP/expired certificate, draft retention, ASCII literal text, cURL import, Return-not-Send, edited-copy cancellation, narrow/wide geometry, and Share sheet normal/fullscreen checks. Final-source Dark flow passed those targeted tests. Native HAR Share displayed the expected JSON attachment and Copy in both normal and fullscreen. No end-to-end exported file roundtrip was verified; do not infer one from Share sheet presentation. Old Mac59 fileExporter experiment evidence does not apply to the final ShareLink implementation.

No new release-blocking failure appeared in this bounded Light capture pass. Store image canvas sizing and release acceptance remain with root.
