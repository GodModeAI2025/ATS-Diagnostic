# Native URL query details

Preview55 sourceaf996a7 adds a native URL-Parameter destination to recorded connections, preserving raw delimiters/duplicates, missing versus empty values, single percent decoding, literal plus and original encoding. Control/bidi characters and backslashes have unambiguous display forms; copied URL remains original. Up to256 parameters and64KiB query data are displayed, with explicit limit messages; original URL is retained.

Five targeted model tests and full157-method native app regression passed (176 parameterized executions, zero failures/skips/runtime warnings). The full regression precedes the two final view-only changes to German wording/raw-control display; the unchanged visibleText helper is covered by the model tests, and final view source was rebuilt and verified natively afterward.

Final iPhone build55 verifies duplicatesa1/a2, flag without assigned value, empty value, literala+b, café&x, a=b, expanded original percent encoding and no-query empty state. iPad landscape and largest Dynamic Type verify readable/scrollable content. Own QA sessions closed; iPad orientation/font size restored. PNG/AX files preserve these checks.

The conditional final-destination query link is present in code; separate native redirect-destination navigation, clipboard readback and oversized-query UI are not claimed. Their parsing/display boundaries are model-tested where applicable. No request/network result or recorded source is changed by viewing query data.

Signed archive55 and upload succeeded2026-10-12T13:39:06+02:00. Processing/group availability is tracked separately in ../TestFlight55/Status.json. App source/resource changes do not include the separate developer SDK. Original Store50 submission remains untouched. Full historical combined scope remains open.
