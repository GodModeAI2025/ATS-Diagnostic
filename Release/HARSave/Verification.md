# Direct HAR Save As — macOS

The Mac History toolbar now opens the native Save As dialog directly. It exports a snapshot of the entire current history using the existing HAR Transferable representation and `.har` type. The file exporter is attached to the outer NavigationStack, matching the previously verified fullscreen importer placement. Cancellation releases the snapshot; write failures show a localized alert. The iOS share flow is unchanged.

## Automated checks

- Mac Catalyst regular signed build: passed (`work/HARSave-MacBuild.log`).
- iOS Simulator build: passed, including Xcode MCP BuildProject (`work/HARSave-XcodeBuild.json`, `work/HARSave-iOSBuild.log`).
- 21 tests in four suites passed: HARTests, ExternalHARTests, SDKHARImportTests and HistoryPersistenceTests (`work/HARSaveTests.log`, `work/HARSaveTests.xcresult`). These include actual Transferable file output and round trip, millisecond timestamps, UTF-8/binary content, malformed input and retained history/provenance.
- German localization syntax and git diff whitespace checks: passed.

## Native validation

- Normal window: native Save As saved `ATS-Normal.har` directly, with 101 entries and 371157 bytes.
- Fullscreen: native Save As saved a Unicode filename containing German and Japanese characters, with the same 101 entries and byte-identical payload. The Save button was enabled.
- Export cancellation created no file; reopening the dialog worked.
- Existing own QA file: the native replacement prompt appeared; cancellation preserved bytes and modification time, then confirmed replacement wrote the file successfully.
- History remained at 101 records and 19 failures; no records were removed.
- Parent independently parsed both saved files and verified identical SHA-256 `763e6d018f956b0dd7e195ca216ebc8d446e6be2136c6976da2973a14c2286ef`.
- Captured fixture history contains only example.com and expired.badssl.com, no URL credentials, request bodies or authentication/cookie headers.
- Focused independent code review found no actionable issue. Native screenshots, AX captures, exported files and detailed QA are retained in QA/.

## Distribution

This change has not been uploaded or submitted to Apple. Existing release evidence remains under Mac61/.
