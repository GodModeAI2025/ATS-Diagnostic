# Mac60 design audit — current Mac59 UI

Four fresh native captures, 2026-10-27. Existing app binding only, no launch/build. Read-only navigation among tabs; no settings, diagnostic data, code or release state changed. Images are exact JPEG capture bytes, 2048 x 1536, with full AX snapshots. System capture indicator and cursor are not app design. Inactive-window title/toolbar dimming must not be mistaken for static product contrast.

## Biggest issues

1. **Oversized mobile layout on Mac.** Across all four screens, large rounded cards, large gaps and full-width pill actions consume most of the window. Information density is low despite a technical desktop task. History shows only roughly seven records in a 1536-pixel-tall capture; important technical comparisons require scrolling.
2. **Weak hierarchy through repetition.** Inspect repeats Verbindung prüfen in navigation title, card title and primary action, adds a marketing-style headline and application illustration, then repeats success/status/URL in the result. One compact input bar plus a clear destination/status header would establish a stronger reading order.
3. **Navigation does not organize the diagnostic workflow.** Four equal titlebar tabs dominate the header. Local actions float far right with mostly unlabeled icons, especially five icons and truncated search in History. A stable Mac sidebar and contextual toolbar could make destination and available actions easier to discover.
4. **History sacrifices comparison for decoration.** Large repeating exchange icons and three-line records replace aligned columns for destination, method, status, time, and duration. The left summary is disproportionately large, including awkwardly wrapped Durchschnittliche Dauer; a compact summary strip and sortable table would prioritize actual records.
5. **Requests breaks the input task into distant blocks.** URL/method, generic explanatory text, optional fields and Send are separate tall regions; Send lies far from URL. Raw HTML dominates the response card without syntax structure or tabbed response categories. A compact request editor and response inspector would improve scanning.
6. **Tools gives supporting information more prominence than work.** An empty black editor has little affordance; address resolution and conversion live in one card without clear relation. The privacy card is visually heavier than the empty result. Result and input should dominate; privacy belongs in a quieter support surface.
7. **Current-state context is unclear after launch.** Inspect/Requests URL drafts are empty while the last HTTP result remains visible. This is real persisted history, but the large result can appear attached to an unentered target; label the timestamp and destination prominently as a previous result.

## Evidence

- 01-Inspect.jpg / 01-Inspect-AX.txt
- 02-Requests.jpg / 02-Requests-AX.txt
- 03-History.jpg / 03-History-AX.txt
- 04-Tools.jpg / 04-Tools-AX.txt

No redesign implemented during this audit. Primary recommendation: structural Mac layout, density and hierarchy changes before further decorative changes. Muted accent colors alone do not resolve these problems.
