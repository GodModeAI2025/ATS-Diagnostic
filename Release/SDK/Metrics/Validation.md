SDK Foundation metrics

All37 macOS SDK test methods passed with Live enabled. Native iOS controlled run:30 passed,7 Live methods skipped intentionally. Native new-metrics Live run:3 methods passed,0 failures/skips (example.com metrics; enbw.com host redirect decision; expired.badssl.com and wrong.host.badssl.com preserved rejection).

Optional metrics capture covers data, Data/file uploads, downloads, byte streams and structured stream scopes. Existing defaults remain unchanged. Objective-C callbacks are forwarded to the supplied host task delegate or existing session task delegate; no authentication/trust handler is introduced. The metrics callback is observed and forwarded. Controlled tests verify redirect/completion callback forwarding and unchanged transfer bodies/files/stream counts; Live tests verify actual HTTP/TLS behavior. This does not prove compatibility with every possible host delegate.

Native metrics are preserved separately from body-consumption time and HAR aggregate timings. Missing phases stay unknown.128-transaction cap and total/truncation metadata are explicit. Main app Build50 does not embed this developer package; its submitted binary remains unchanged.
