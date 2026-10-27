# Native UI QA — 2.0.1 (56)

Verified 2026-10-27 using Xcode MCP workspace-backed builds and native UI screenshots/hierarchies. Full PNGs use unscaled simulator framebuffers via `simctl io screenshot`.

- Four tabs: Inspect, Requests, History, Tools. No Erfassen/proxy tab on phone or iPad.
- Actual `http://example.com` returned HTTP 200 with TLS not reported and zero certificates.
- Actual `https://expired.badssl.com` failed default certificate trust; readable expired-certificate cause and next step remained visible.
- Actual HTTPS example.com returned 200/TLS 1.3/four evaluated certificates. Structured issuer and next-certificate navigation visible.
- TLS version probes were not rerun in this round.
- Physical-device installation and behavior were not verified in this round; these are simulator results.
- iPad after keyboard use showed a retained bottom inset on Requests/Tools. A cold native app relaunch, without keyboard interaction, cleared it. Use the `iPad-Requests-Cold` and `iPad-Tools-Cold` images, not the earlier captures. No source fix was made during QA.
- All created UI sessions ended. No portal, source, signing, or entitlement changes were made by this QA agent.

## Screenshot sets

- `Medium-{Inspect,Certificate,Requests,Tools}.png`: native 1206 × 2622, required medium phone set; corresponding `.txt` AX hierarchy.
- `iPhone-{Inspect,Certificate,Requests,Tools}.png`: native 1320 × 2868, large phone set; corresponding `.txt` AX hierarchy.
- `iPad-Inspect.png`, `iPad-Certificate.png`, `iPad-Requests-Cold.png`, `iPad-Tools-Cold.png`: native 2752 × 2064 landscape; corresponding `.txt` AX hierarchy.
- `iPhone-HTTP-QA` and `iPhone-Expired-QA`: MCP-sized functional proof, not App Store submission images.

Own replacement devices: iPhone Pro Max F5580700-D243-47FE-B2F0-B98CC4B90B1E; iPad F5E9383C-83DD-4E40-8D02-583190DD4765. Required medium captures used the explicitly authorized parent test phone 1B8C4009-BDAF-4782-BB8F-064943B0CB6F after tests finished.
