# HAR native roundtrip — 2026-10-27

Existing Mac60 Debug app supplied by root (last known PID 38500). No source/build changes. Native CUA exclusively used for app/Finder interactions. Existing history was not cleared.

## Observed successful roundtrip

1. History before export: 16 records, 3 errors, 7 kB response data.
2. HAR export opens native Share popover. There is no direct Save/Save to Files action in this environment; Copy is enabled. Attachment displayed as ATS-Diagnostic.har, JSON, 58 KB.
3. Clicked Copy; navigated Finder directly to this QA/HAR directory; used Cmd+V. Actual file materialized as ATS-Diagnostic.har.json, 57,697 bytes. Finder also materialized ATS-Diagnostic.har 2.json after the one paste call; both files are byte-identical and retained as evidence. This duplicate is observed but cause is not isolated.
4. Read-only Python validation: JSON parse succeeds, log.entries contains 16 records. URLs only example.com and expired.badssl.com (including prior example.com QA paths/query strings).
5. Imported exact ATS-Diagnostic.har.json via app HAR import native Open panel.
6. History increased from 16 to 32 records, errors 3 to 6, response data 7 to 14 kB. Original history retained.
7. First imported record explicitly says Importierte Aufzeichnung and that import did not recheck the connection. HTTP 200, duration and original date retained; TLS/certificates are not asserted (Nicht gemeldet / 0). The displayed SHA-256 is labelled as from the imported record and not newly verified.

SHA-256 for both exported files: f86e0b9d4741bceba3d1aff1e80b2a8b4b45eb2a2413ee903889df0bd3d97de2

## Fullscreen and cancellation

Entered native View > Full Screen. HAR Share opens with JSON 116 KB (32 records now) and enabled Copy; Escape dismisses. HAR import opens native Open panel; Cancel dismisses. History remains 32 records, 6 errors. Did not repeat actual Finder file materialization/import in fullscreen, so the proven complete file roundtrip is the normal-window path.

## UX limitations

The functional file roundtrip works, but Share > Copy > Finder > Paste is indirect and undiscoverable for users expecting Export to save a file. No direct save action was available. Actual filename has .har.json suffix, while Share presentation abbreviates it to .har. Finder produced a byte-identical second file during this one paste flow; cause not isolated. These are distinct from JSON/import correctness.

## Evidence

01-History-Before: initial count screenshot/AX.
02-Share-Normal-AX: available actions.
03-Finder-Exported: actual files in target folder screenshot/AX.
04-Reimport: 32-record result screenshot/AX.
05-Imported-Provenance: imported-record warning screenshot/AX.
06-Fullscreen-Share-AX: fullscreen available export actions.
07-Fullscreen-Cancel: unchanged count after both cancellations screenshot/AX.

Waiting for parent new-build READY to verify certificate localisation. No further UI operations until READY.
