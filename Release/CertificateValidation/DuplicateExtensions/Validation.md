# Duplicate X.509 extensions — 2026-10-27

The common X.509 field decoder previously returned multiple fields with the same extension OID. CertificateAnalysis then constructed a dictionary with uniqueKeysWithValues, which requires unique keys and can trap for that input. The decoder now rejects duplicate extension OIDs before either dictionary construction or SwiftUI field identity handling. A failed field decode yields a readable structure finding; original DER export and system trust evaluation remain unchanged.

RFC 5280 section 4.2 prohibits duplicate instances of a certificate extension: https://datatracker.ietf.org/doc/html/rfc5280#section-4.2

Evidence:
- Regression-Before.log: the duplicate-extension regression failed because no error was thrown; the single-extension control succeeded.
- Targeted-After.log: 11 tests in ASN1Tests, CertificateFieldTests and CertificateIssuerTests passed, including the CertificatePresentation path and the structure finding.
- Full-After.log: 160 app test methods in 35 suites passed on the existing iOS 27.2 simulator.
- Fixture deliberately exercises the field decoder; it is not a cryptographically valid certificate and does not demonstrate a server-side exploit.

This source correction was made after Store/TestFlight build 56. It is not included in that uploaded binary, and no new archive/upload/review replacement was performed. Physical-device behavior and visual presentation were not rechecked for this correction.
