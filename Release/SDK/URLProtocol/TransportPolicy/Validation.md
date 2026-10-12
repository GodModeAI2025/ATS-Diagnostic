# Explicit forwarding-transport policies

RecordingProtocolContext accepts an optional transportDelegate. Objective-C forwarding exposes its unimplemented task/session selectors to Foundation, including redirect and authentication decisions. The SDK-owned metrics and completion callbacks additionally notify that delegate. No new authentication disposition or certificate credential is chosen by the SDK.

Full live-enabled suites passed55 methods on macOS and native iOS27 Simulator; iOS records63 parameterized executions, zero failures/skips/runtime warnings. Existing success/default-rejection/POST/cancellation/isolation tests remain green. The two new native tests prove:

- enbw.com redirect rejected by the host transport delegate returns its original HTTP301 response, zero followed redirects, one native metrics callback and one successful completion callback.
- example.com server authentication cancelled by the host transport delegate produces NSURLErrorDomain/-999, identical recorded/returned/completion errors, incomplete response and no complete SHA256.

The initial new checks did not compile before the transportDelegate argument existed. Targeted.log and both full-suite logs provide runtime proof afterward. No credential or accept-all trust fixture is used.

Callbacks refer to internal forwarding sessions/tasks on their delegate queues. The context retains the delegate for its lifetime; one delegate may receive concurrent callbacks from several forwarding sessions. This is explicit policy integration, not transparent identity/callback parity with an existing or outer host URLSession. Data response-disposition callbacks, externally installed task-specific delegates and complete cache/cookie parity remain open.

SDK-only change: no App source/resources, signed archive, uploaded TestFlight54 or original Store50 submission changed. Full historical combined scope remains incomplete.
