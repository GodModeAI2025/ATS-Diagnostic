# Explicit exact-URL rewrite model

The first rewrite model supports matching an exact HTTP(S) URL and replacing its target, method, named headers or body. It returns a new request and preserves the original. Replaced bodies are reframed with a single correct Content-Length, removing chunked framing/trailers. Cross-origin maps remove old Authorization/Cookie values; same-origin maps retain them. Managed framing/connection headers, duplicate case-insensitive header overrides, credentials/fragments in mapped URLs, CONNECT conversion and opaque CONNECT/upgrade rewrites are rejected. Body replacements are capped at16MiB.

Six native iPad test methods passed: chunked→fixed body framing with original preservation; cross-origin credential isolation; exact-match/no-match wire preservation and managed-header rejection; same-origin credential/chunk preservation; CONNECT/upgrade guards; explicit target validation.

This model is not yet connected to the running proxy or its UI. Whole proxy rewrite/map/breakpoint functionality is not complete. Regex matching, response rewriting, persistent rule controls and runtime changes remain open.
