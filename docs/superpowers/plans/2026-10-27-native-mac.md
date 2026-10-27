# Native Mac Workspace Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task-by-task. Existing user-authorized agents support implementation and native QA.

**Goal:** Implement the user-approved native Mac concept with compact controls, persistent sidebar, flat result sections, and system appearance.
**Architecture:** Retain the existing TabView and its per-tab state. Apply Catalyst-only layouts and shared styling; keep data/security/export logic and iOS layouts unchanged.
**Tech Stack:** SwiftUI, Mac Catalyst, existing Xcode project and tests.
**Spec:** Release/Mac60/Design/Design.md and Native-Mac-Concept.png, explicitly approved by the user on 2026-10-27.

## Global Constraints
- Existing app 1297164068, bundle com.mobilebox.atsdiagnostic; macOS 15+.
- No new dependencies, network behavior, proxy, VPN or trust bypass.
- System Light/Dark appearance; accessible labels and adaptive layouts.
- Generated concept is not a Store screenshot. Capture actual final app for release assets.

## Review Focus
- Drafts must persist when changing sidebar destinations; native QA task 3.
- Narrow windows must retain the action and all values; native QA task 3.
- Edited-request sheets must preserve cancel/close and explicit send semantics; task 3.
- HTTP and certificate failures must remain distinct from successful secure transport; task 3.
- Existing share menus and detail back-navigation must remain reachable; task 3.

### Task 1: Mac shell and primary screens
Files: App/ATSDiagnosticApp.swift.
- [x] Keep TabView, add native adaptable sidebar only for Catalyst; inspect actual runtime behavior.
- [x] Inspect: compact URL/action row, result identity/time, flat metric strip, certificate rows beside timings, existing detail destination.
- [x] Requests: compact method/URL/send bar; optional editors beside response; preserve state/import and edited-copy behavior.
- [x] History: filters/brief statistics above full compact list; preserve existing actions.

### Task 2: Shared Mac components and tools
Files: App/VisualComponents.swift, App/Tools.swift, App/de.lproj/Localizable.strings, App/en.lproj/Localizable.strings.
- [x] Mac-only compact symbols, neutral surfaces, flat separators and metrics; keep iOS rendering.
- [x] Tools: operation/action row and input/output workspace; subordinate privacy footnote.
- [x] Add translations for new labels and validate strings syntax and duplicates.

### Task 3: Integrate and verify
Files: project.yml, generated project, Release/Mac60/.
- [x] Build Mac and iOS; run existing applicable regression tests.
- [x] Native QA the five review conditions plus Light/Dark, HTTPS success/HTTP cleartext/expired certificate, tools output.
- [x] Fix visual issues from actual screenshots; archive/upload only after checks pass.
- [x] Capture current real Store screenshots, replace rejected Mac59 Store draft with new build and assets, verify submission result if authorized release gates permit.
