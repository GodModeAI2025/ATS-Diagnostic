# Final Build 59 native QA — 2026-10-27

Final ShareLink build, single process PID 80849 confirmed by parent before testing. No code/build/release actions by QA agent.

Verified live: HTTP example.com 200 explicitly Unverschlüsselt; HTTPS example.com 200 TLS 1.3 and four certificates; Return submits; Requests GET 200 and response body; issuer SSL Corporation / Cloudflare TLS Issuing ECC CA 3; expired.badssl.com rejected with Zertifikat abgelaufen and concrete next step; Base64 conversion of ATS Diagnostic returns QVRTIERpYWdub3N0aWM=. All four tabs navigable. Native normal-window scrolling works.

Final exports: original System ShareLink restored by parent. HAR share popover opens normally and in native fullscreen, showing ATS-Diagnostic.har / JSON / 20 KB. Copy action is enabled and dismisses correctly in both modes. No external recipients/services selected. Optional Finder paste into new QA/ShareCopy folder produced no file; clipboard/file round-trip is therefore unverified. Do not claim successful final-build file save based on earlier discarded fileExporter experiment.

Six real dark-mode screenshots with full AX snapshots are saved here. Native capture returned JPEG bytes despite earlier .png filenames; extensions corrected to .jpg without image manipulation. All are 2048x1536 and NOT accepted Mac App Store dimensions. Both targeted native corner-drag coordinate interpretations failed to change size; bounded attempt stopped. Native fullscreen earlier gave 3024x1898, also not a supported Store size. Screenshot includes system screen-sharing indicator and pointer; these are actual capture artifacts, not app content.

Visual review: clear contrast, muted colors, useful two-column Inspect/Requests/Tools layouts, readable error explanation. Certificate view remains a wide single-column form with mixed English/German field labels; a localization/layout polish opportunity, not a crash or hidden value. Some long content extends below viewport and scrolls normally. No synthetic Store screenshot content was created.

Known discarded-experiment findings: fileExporter Save disabled in fullscreen under both Transferable and FileDocument, confirmed with single process. This extra save implementation has been removed; the final app uses System ShareLink. Earlier swapped toolbar observation was caused by two concurrent identical app processes, not established as an app defect.
