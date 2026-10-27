# Build61 HAR QA

CFBundleVersion on disk verified 61. Initial stale handle hit old Mac60 instance; root removed old/testhost processes and confirmed single Build61 PID59981. All Build61 HAR checks below occurred after rebinding the exact app path.

Native export actually saved files in Normal and Fullscreen directories. Both correct ATS-Diagnostic.har extension, 120848 bytes, valid JSON HAR, 33 entries. SHA256 7a042ed43938e74929d4266e183eae940d9b131b4ed3fda05fc6688897f414cf. All five files in File-Validation.txt are byte-identical.

Cmd+V once in each empty directory produced two identical files. No duplicate Copy/Paste action or retry was issued. Finder menu showed '2 Objekte einsetzen' for the clipboard, but a single click of that menu command into fresh MenuPaste produced only one file, even after readback. Thus duplication is not isolated as an app defect; automation shortcut/file-promise interaction may be involved. Production code should not be changed solely on this ambiguous evidence.

BLOCKER: Importing MenuPaste/ATS-Diagnostic.har in the native Open panel selects the file but leaves Open disabled. Panel identifies the file as Reiner Text. No forced open or extension rename attempted. 05-HAR-Import-Disabled screenshot and AX capture this. Cancel succeeded; history remains 33 records and 6 errors. No Build61 reimport has occurred yet. Previous Mac60 .har.json roundtrip success does not prove corrected .har import.

Normal and fullscreen export-to-disk are proven. Fullscreen import cancellation is proven. Awaiting root file-type/localisation rebuild before remaining import and final certificate checks.

## Final binary follow-up (PID65659, confirmed by root)

The earlier import blocker was isolated to fullscreen. After native View > Exit Full Screen, exactly the same .har file had enabled Open. The old .har.json baseline also had enabled Open in the same normal dialog. Actual .har imported once successfully: 33 -> 66 records, errors6 ->12. Evidence08/09 selection states,10 final reimport,11 import provenance. Imported record explicitly states it was not rechecked; TLS/certificate trust is not fabricated. A later expired.badssl QA request adds one record (67 total).

Normal-window roundtrip is fully proven. Fullscreen export-to-file succeeds; fullscreen import Open remains disabled in this binary. Root is testing presentation attachment fix; final status pending.

## Final root-NavigationStack presentation fix

After new launch, selected identical .har in fullscreen now has enabled Open (12-RootPresentation-Fullscreen). Initial cancel left67 records. Parent requested full import: exactly33 entries imported,67->100 records and13->19 errors (14-Fullscreen-Reimport). Imported-record provenance confirmed (15-Fullscreen-Provenance).

A parallel testhost briefly confused navigation; after root removed all processes and authorised a clean restart, imported detail->Back correctly restored export/import toolbar. Import reopened and cancelled; HAR Share reopened with367KB attachment and Copy. History remained100. Thus toolbar issue was not reproduced in uncontaminated single instance.

Normal and fullscreen actual export-to-file and actual import are proven. Final file name .har correct; data validated. Direct Save action still absent by design; system Copy/Finder-menu Paste is the verified file workflow.

Last Store capture attempt encountered CUA menu-only AX with screenshot unavailable; app still running. This is a tooling observation, not a demonstrated product defect. Parent notified.
