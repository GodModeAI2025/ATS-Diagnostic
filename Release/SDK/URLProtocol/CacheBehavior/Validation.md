# Foundation cache behavior

The existing automatic URLProtocol implementation passed the new integration checks without a production-code change. The fixture owns a memory-only1MiB URLCache with disk capacity zero and a synthetic cached HTTP200 response. No shared user cache is cleared or modified.

The baseline Foundation session and recording session return identical cached bytes under returnCacheDataDontLoad and useProtocolCachePolicy. Two recording-session calls produce two independent complete journal entries, retaining response bytes/preview/status and native localCache transaction metrics. Fresh Date/max-age metadata supports the protocol-cache-policy case.

reloadIgnoringLocalCacheData does not return that seeded response. Against the unresolvable synthetic fixture domain, baseline and recording sessions return matching original error domain/code; the recorded entry preserves that actual failure, without status or complete hash. This is a real native Foundation cache/bypass check, not a replacement cache implementation.

The full live-enabled SDK suite passes57 methods on macOS and iOS27 Simulator; iOS summary proves66 parameterized executions, zero failures/skips/runtime warnings. Existing live HTTPS, redirects, default certificate rejection, explicit transport policies, POST, cancellation, streaming and journal isolation remain green.

Scope: manually populated memory-cache hits and explicit bypass. Automatic server-populated cache, HTTP304 revalidation, Vary, cache delegate decisions, cookies across origins/redirects and full existing/outer-session parity remain open. No overall cache-parity or historical-parity completion claim is made.

Only tests/documentation changed. No signed app binary, TestFlight54 availability settings or Store50 submission changed.
