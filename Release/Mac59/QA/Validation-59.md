# Mac Catalyst Build 59 native QA

Date: 2026-10-27. Production sandbox debug app launched by parent via Xcode. No production code edits, builds, signing, uploads or portal actions by QA agent.

## Verified

- HTTP example.com completes with status 200; German main labels and darker primary action are readable. Plain HTTP explicitly says Unverschlüsselt with open-lock icon. See 01-HTTP200.
- Native normal-window HAR Save succeeds: ATS-Diagnostic.har, 20082 bytes, valid JSON with 6 entries. Automatic .har extension correct.
- Native normal-window complete certificate-chain PEM Save succeeds: ATS-Diagnostic-chain.pem, 4479 bytes, 4 BEGIN CERTIFICATE blocks. Automatic .pem extension correct.
- HAR and PEM native Cancel both dismiss the dialog without losing history.
- Fullscreen reached and exited with observed Darstellung > Vollbildmodus / Vollbildmodus aus menu items, not an inferred key shortcut. Native fullscreen capture is 3024 x 1898; normal capture is 2048 x 1536.

## Release blocker / platform behavior to investigate

In native fullscreen, both HAR (toolbar) and complete PEM chain (list-content button) present native save panels with Sichern and Neuer Ordner disabled. Reproduced HAR twice after successful normal-window export, then PEM as independent control. Expanding the panel and explicitly selecting the existing QA directory does not enable Save. Name field remains ATS-Diagnostic despite click, Cmd-A, paste and Tab; keyboard focus moves to Search. This may involve fullscreen/native panel focus or platform behavior, but no root cause is established. Do not label it a confirmed app-code bug without further investigation.

Evidence: 03-HAR-Save-Disabled, 04-HAR-Fullscreen-Expanded, 05-PEM-Fullscreen (PNG and full AX snapshots).

## Remaining limits

- CUA scroll in fullscreen throws noWindowsAvailable, although Page Down keyboard navigation works.
- Build 58 already covered HTTPS 200, TLS1.3, expired certificate rejection, Requests, History, certificate issuer and HAR import. Those results remain in Release/Mac58/QA; not all are freshly repeated on 59 yet.
- No accepted-size final Store screenshots yet. Only actual native captures are saved.
- UI paused after PEM Cancel on parent request; app remains fullscreen in HTTPS connection details.
- History includes one controlled imported HAR fixture; do not use that entry in Store screenshots.


## Single-process control, 19:36 local

Parent verified exactly one Xcode app process, PID 78955. CUA rebound to exact DerivedData app. Navigation was normal. The earlier swapped toolbar observation happened with two app processes and is not a valid product defect.

FileDocument HAR variant saved in normal window but appended .json, producing HAR-FileDocument-Normal.har.json. File parses as JSON with 6 HAR entries. Fullscreen Save remained disabled. The original Transferable PEM chain export also remained disabled in fullscreen. Both cancelled successfully with Escape. Evidence 06-FileDocument-Fullscreen-SingleProcess and 07-PEM-Fullscreen-SingleProcess (PNG + full AX).

No further variants attempted. UI paused on HTTPS details in fullscreen for parent fix.
