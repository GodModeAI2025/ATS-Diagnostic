# Build61 native certificate localisation QA

Final PID65659 supplied by root. All final screenshots are genuine CUA JPEG, no image editing. Final-Deutsch-Aussteller.jpg is2048x1538 and shows German holder/issuer labels and original CA names.

Verified in native UI: Zertifikat/Serverzertifikat, Zertifikatsinhaber, Zertifikatsaussteller, validity and explanations, Fingerabdruecke, root-store explanation, CT navigation/qualification/log metadata, Elliptische Kurve256Bit, key identifiers, metadata/version/serial/source, ECDSA mit SHA-256/OIDs, extension headings and values such as Zertifizierungsstelle:Nein, Digitale Signatur, TLS-Serverauthentifizierung. Certificate Transparency is retained as protocol term. CN/DNS/URLs/hex/OIDs/issuer names unchanged.

expired.badssl.com rejected with Zertifikat abgelaufen, explanation and actionable next step. Certificate Findings say Gültigkeit endete am13.4.2015. Header uses Laeuft am...ab even for old date (minor tense inconsistency, does not hide failure). Screenshots Final-Expired-Error and Final-Expired-Findings.

No overlap/cropping defect found in normal2048x1538 window while scrolling these views. Other connection-detail labels such as Favorite/Protocol/Connection map remain English outside the requested certificate flow.

00-OldLabels evidence was captured from old Mac60 instance before root removed duplicate processes; it is not evidence of a Build61 localisation defect.

Final follow-up: neutral header Gültig bis … and explanation alternative Zertifikatsnamen verified in the last clean build. Store-Final-Aussteller.jpg and Store-Final-Erklaerung.jpg are the authoritative final unmodified dark originals. Pointer moved into empty sidebar; OS capture indicator retained.
