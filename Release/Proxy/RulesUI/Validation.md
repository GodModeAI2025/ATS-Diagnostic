# Native proxy rule controls

The capture tab now exposes exact-URL rule creation, enable/disable, editing, deletion and ordered precedence. Configurations compile before proxy start; an immutable enabled-rule snapshot is supplied to the relay. UTF-8 text, Base64 binary bodies and explicitly empty replacement bodies are distinct from unchanged content. Field validation retains framing and origin guards. Captures display rule application and original target.

Rules are currently session-only, explicitly disclosed in UI. Controls are disabled while running and model mutations independently enforce the same guard, including editor-save races. At most64 configurations can be added. Persistent profiles, regex/response rewrites and breakpoints remain open.

Full native app suite passed (see Tests.json); new cases verify binary body round-trip through actual HTTP framing, empty-body distinction and model order/running guards. Existing runtime tests prove real loopback mapping and cross-origin credential removal. Native rule-editor/proxy UI verification is pending. TestFlight53 is unchanged and does not contain these controls.
