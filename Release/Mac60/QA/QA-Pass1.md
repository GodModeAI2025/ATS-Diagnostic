# Mac60 first native redesign QA

Single running Xcode app identified by parent PID2203. QA used existing app binding; no launch, build, source edits or release operations.

Passed live: HTTPS example.com 200/TLS1.3/4certs; HTTP example.com 200 explicitly Unverschlüsselt; expired.badssl.com rejected with clear Zertifikat abgelaufen reason and next step; issuer SSL Corporation/Cloudflare TLS Issuing ECC CA 3; certificate back navigation. Request URL/header/body retained across sidebar changes without sending. Tools input ATS Mac60 and Base64 QVRTIE1hYzYw retained across sidebar changes. Edited-copy sheet opened and closed via Schließen, no Send/Return action.

Confirmed fix request: technical Body typing converted ASCII JSON quotes to smart quotes. Parent accepted and is implementing technical editor substitution controls. Header/body were only local drafts and never submitted.

Visual: new sidebar and flat sections improve hierarchy over old cards. Root will fix uneven wide metric columns and compact timing bars. Certificate detail remains a mixed-language older form.

Bounds: earlier screenshots 06/09 include a white right edge and cropped content. Titlebar drag did not isolate cause. Native Window > Fill produced a complete 3024x1790 capture with all tool controls inside frame (10). Window > Move & Resize > Left produced 1514x1794 with stacked Tools and Requests and reachable Send (11/12). Earlier clipping is not a clean app-overflow proof because native tiling removed it.

Pending final build: verify smart quotes fix, Return in edited-copy cannot send, partial badge, revised metrics/timings, share normal/fullscreen, Light app-scoped appearance. App currently narrow on Requests with local draft; QA paused for parent tests/restart.
