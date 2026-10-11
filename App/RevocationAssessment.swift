import Foundation
import Security

struct RevocationAssessment: Codable, Sendable {
    enum Status: String, Codable, Sendable { case good, revoked, inconclusive }
    let status: Status
    let checkedAt: Date
    let detail: String
    let evidence: [ErrorEvidence]
    static func check(_ record: DiagnosticRecord) async -> Self {
        let certificates = record.certificates
        let host = URL(string:record.finalURL ?? record.url)?.host
        let systemResult = await Task.detached(priority:.userInitiated) {
            let date = Date()
            let objects = certificates.compactMap { SecCertificateCreateWithData(nil,$0.der as CFData) }
            guard !objects.isEmpty, let host, let policy = SecPolicyCreateRevocation(CFOptionFlags(kSecRevocationUseAnyAvailableMethod | kSecRevocationRequirePositiveResponse)) else { return Self(status:.inconclusive,checkedAt:date,detail:"Keine auswertbare Zertifikatskette für die Sperrprüfung vorhanden.",evidence:[]) }
            var optionalTrust: SecTrust?
            let created = SecTrustCreateWithCertificates(objects as CFArray,[SecPolicyCreateSSL(true,host as CFString),policy] as CFArray,&optionalTrust)
            guard created == errSecSuccess, let trust = optionalTrust else { return Self(status:.inconclusive,checkedAt:date,detail:"Die zusätzliche Prüfung konnte nicht eingerichtet werden.",evidence:[]) }
            SecTrustSetNetworkFetchAllowed(trust,true)
            var error: CFError?
            let valid = SecTrustEvaluateWithError(trust,&error)
            let evidence = error.map { ErrorEvidence.capture($0 as Error) } ?? []
            let result = SecTrustCopyResult(trust) as? [String:Any]
            let checked = result?[kSecTrustRevocationChecked as String] as? Bool
            if evidence.contains(where: { $0.domain == NSOSStatusErrorDomain && $0.code == Int(errSecCertificateRevoked) }) { return Self(status:.revoked,checkedAt:date,detail:"Die zusätzliche Systemprüfung mit angefordertem positivem Sperrnachweis meldet einen Widerruf.",evidence:evidence) }
            if valid && checked == true { return Self(status:.good,checkedAt:date,detail:"Die zusätzliche Systemprüfung hat eine gültige Sperrauskunft ohne gemeldeten Widerruf bestätigt. Das Ergebnis gilt für diesen Zeitpunkt und diese Kette.",evidence:evidence) }
            return Self(status:.inconclusive,checkedAt:date,detail:"Kein positiver Sperrnachweis bestätigt. Ursache kann eine nicht erreichbare Auskunft oder ein anderer Zertifikatsfehler sein. Das bedeutet weder sicher widerrufen noch sicher nicht widerrufen.",evidence:evidence)
        }.value
        if systemResult.status == .inconclusive, let crlResult = await SignedCRLAssessment.check(record) { return crlResult }
        return systemResult
    }
}
