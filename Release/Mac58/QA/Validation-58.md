# Mac Catalyst native QA — build 58

Native app tested through CUA after Xcode MCP launched its production-entitlement Debug build. Bundle: `com.mobilebox.atsdiagnostic`. Xcode product: `/Users/markzimmermann/Library/Developer/Xcode/DerivedData/ATSDiagnostic-dwqsvugqytkzgnfrfturllqkowje/Build/Products/Debug-maccatalyst/ATSDiagnostic.app`.

## Confirmed through visible UI

- Inspect text field accepts a URL and Return starts the request. `http://example.com` returned HTTP 200.
- `https://example.com` returned HTTP 200, TLS 1.3, four chain certificates; record details showed system trust passed. Certificate view displayed validity dates and issuer SSL Corporation / Cloudflare TLS Issuing ECC CA 3.
- `https://expired.badssl.com` failed with the readable German explanation “Zertifikat abgelaufen”, validity explanation and next steps. Trust was not bypassed.
- Requests GET to `https://example.com/?source=ats-mac` returned HTTP 200 and visible response body.
- History displayed the four native requests with one failure.
- Export HAR generated a 15 KB HAR in the native Share sheet. No recipient was selected, and no data was sent. This sheet offered sharing/Copy, but no visible Save As action; persistence to a user-chosen file was not verified.
- Import HAR opened a native macOS file chooser. Selecting `Import-QA.har`, a controlled local one-record fixture, added the fifth history item. Fixture is explicitly synthetic import evidence, not a live network result or Store screenshot subject.
- Tools opened, and Base64 output corresponded to the input text displayed by the tool. CUA text editor typing/selection was inconsistent, so precise keyboard editing behavior is not claimed.
- Native window menu → Move & Resize → Left changed captured window dimensions from 2048×1536 to 1514×1782. Certificate content remained readable. Arbitrary border dragging did not resize; exact 16:10 Store dimensions remain unverified.
- An external test-host restart reset active tab/input while preserving imported history. This is not an isolated controlled relaunch test.

## Design findings for the follow-up build

- Primary action label is white on a pale turquoise fill and appears low contrast.
- App name is duplicated in the title area and Inspect navigation title.
- Main navigation/labels mix English with German hero, trust and error content.
- Certificate details remain a very wide single-column list at the largest size.
- Native export should offer a direct Save As flow rather than relying solely on a sharing sheet.

Parent is addressing targeted UX changes in build 59. These captures are pre-fix QA evidence, not final Store screenshots.

## Evidence and limitations

PNG files 01–09 are actual app-window captures. Several matching AX files contain only diffs/no-change messages; complete readbacks were inspected in tool responses. `09-HAR-Imported-AX.txt` is a full tree. `10-Relaunched-Inspect*` records the externally restarted state, not Tools.

No physical Intel Mac, OS-minimum-version matrix, local-network target, or direct file-save persistence was checked. Exact narrow-window threshold and final 16:10 screenshot capture still need follow-up after build 59 is ready.
