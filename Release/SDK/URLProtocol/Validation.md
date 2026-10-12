# Automatic developer URLProtocol capture

53 SDK methods passed on macOS with live cases enabled. The native iOS27 simulator result proves53 methods/61 parameterized executions, zero failures/skips/runtime warnings. See iOS-Summary.json and full logs.

RecordingURLProtocol provides the actual URLProtocol adapter; a host subclass supplies an immutable RecordingProtocolContext. makeSession installs that class only in newly created sessions. The forwarding configuration removes SDK protocol classes to prevent recursion. No global registration or HTTP marker header is used. Separate classes/contexts isolate journals.

Controlled integration checks cover150017-byte chunked response/full SHA256/three-byte preview, automatic async and completion-handler data calls, actual POST body/custom headers, matching-context/original-configuration isolation, partial transport failure, streaming cancellation and one terminal journal entry. Native HTTPS cases verify example.com200, enbw.com301→200 with Foundation redirect metrics, and default system rejection of expired/wrong-host certificates. Each recorded error matches the error returned to the caller; baseline and forwarding TLS error codes can differ, so no identical cross-connection code is claimed.

The first POST check failed: URLProtocol.request exposed a one-shot stream while the original Task retained13 bytes of Data. The implementation now recovers that original Data without reading the stream. POST-BeforeFix.log records the failed assertions; Targeted.log and both full suites record the corrected result. The partial-error fixture now delays its error until previously emitted chunks reach Foundation callbacks, following the existing SDK fixture pattern; strict byte-count expectations remain intact.

Up to64 active response accumulators retain at most64KiB each. Beyond that cap, transfer continues and omittedCaptureCount increases. The recorder separately enforces encoded-journal/count/preview limits. These capacity gates are inspected in code; a65-concurrent-native-transfer stress test is not claimed.

Configuration is copied, background configurations rejected, caller-supplied request streams and upload tasks not intercepted. Global/existing-session capture, host-specific authentication/redirect delegate behavior, download capture and complete cache/cookie parity remain unverified or incomplete. This is progress toward combined SDK parity, not completion of that broad requirement.

No app UI or signed app resources changed. This separate Swift package is not embedded in TestFlight54 and does not replace queued Store50. Xcode MCP bridge was checked; its sole visible workspace was an unrelated app, which was left untouched. SDK native builds/tests used the explicit ATSRecording scheme and isolated simulator with local Xcode.
