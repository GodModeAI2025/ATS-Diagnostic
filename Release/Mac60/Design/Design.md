# ATS Diagnostic — native Mac redesign proposal

Status: approved by the user on 2026-10-27; implementation in progress, not released. User rejected the Mac59 design on 2026-10-27. Mac59 remains in TestFlight; Store submission is held.

## Intent
A calm, professional native Mac diagnostic workspace with restrained color, small supportive symbols, concise controls and readable evidence. Preserve all diagnostics, certificate validation, ATS configuration, history, imports/exports and existing iOS layouts.

## Approaches
1. Native Mac workspace (recommended): persistent sidebar, compact address/action strip, flat information hierarchy, compact metric strip, certificate list beside timings. Best fits the user's HIG and professional UX requests.
2. Dashboard: stronger visual cards and richer emphasis. Risks repeating the rejected oversized-card design and reducing information density.

The reference `Native-Mac-Concept.png` is AI-generated design guidance, not a real app screenshot or Store asset. Its sample certificate/timestamp text is illustrative. Implementation must display actual record values and retain qualification of trust/timing results. Follow system Light/Dark appearance rather than forcing light mode.

## Scope
- Root: prefer the existing TabView's native adaptable sidebar to retain each destination's state. Verify Catalyst behavior before choosing a more invasive split-view shell.
- Inspect: one URL/action row; latest result clearly names its own URL and time. A restrained metric strip; certificate issuer rows and timings; direct access to existing detail destinations.
- Requests: method, URL and Send together; optional request editors beside response; preserve drafts and edited-copy semantics.
- History: compact filter area and comparable rows, no dominant statistics card; preserve filtering, favorites, imports and exports.
- Tools: operation/action together, input and output beside each other; privacy explanation subordinate.
- Shared Mac styling: smaller symbols, thin separators, neutral system surfaces, no nested large rounded tiles. No global font scaling or new networking behavior.

## Verification
Native readback in Light/Dark mode and narrow/wide windows, keyboard input, tab-switch draft persistence, certificate/error navigation and existing share menu. iOS regression build. Fresh real screenshots only after implementation; none of the generated concept pixels will be uploaded to the Store.

## Approval
User explicitly approved the native Mac direction and the displayed concept. Do not submit Mac59; implement and verify a new build.
