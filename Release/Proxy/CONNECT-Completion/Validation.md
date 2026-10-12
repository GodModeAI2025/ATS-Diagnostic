# CONNECT completion ordering correction

The previous synchronous fixture teardown improved several runs but did not eliminate the failure. The final Preview54 candidate run reproduced it. A repeated diagnostic run localized NWError50 to the upstream connection-state callback while the client read side and upstream write side were closed, but the final upstream receive and client send callbacks were still pending.

Connected-stream state notifications now remain separately preserved as bounded typed connectionStateIssues. They do not overtake pending I/O callbacks. Actual send/receive callback errors still terminate as failed with original ErrorEvidence and a named direction. TCP read-close requires a completed final content context. Received content is counted/retained even when an upstream receive callback also reports an error. The native test client follows the same callback ordering. Idle/lifetime bounds, certificate validation and transport failure assertions remain intact.

The installed official Apple Network connection.h documents receive completion exactly once, data delivered alongside an error, and final-context completion as TCP FIN. These are the observed completion signals used here.

Full151 native app methods passed, zero failures/skips. The large512KiB CONNECT case ran eight times with exact payload comparison, both byte counts, completed state and opaque-preview assertions. An independent BSD TCP peer using SO_LINGER{1,0} generated a real RST; the proxy remained failed with original transport evidence and a named failure phase. The earlier incorrectly selected zero-test run is not evidence.

Native iPhone success/error UI verification is pending. TestFlight53 and Store50 do not contain this subsequent correction. Preview54 upload remains held until verification is complete.

Native iPhone simulator QA passed: exactly524288 bytes sent/identically received after half-close; capture completed with additional NWError50 preserved separately; opaque preview absent/explanation visible. Real SO_LINGER RST remained failed with Empfang vom Ziel and original NWError54. Proxy, fixtures and device session stopped/closed. See CONNECT-Fix-* screenshots and AX.
