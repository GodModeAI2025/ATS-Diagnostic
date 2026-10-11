import Foundation
import Security

struct ErrorEvidence: Codable, Sendable, Equatable {
    let domain: String
    let code: Int
    let message: String
    let sslCode: Int?
    static func capture(_ error: Error) -> [Self] {
        var results: [Self] = [], seen = Set<ObjectIdentifier>()
        func visit(_ value: NSError, depth: Int) {
            guard depth < 5, seen.insert(ObjectIdentifier(value)).inserted else { return }
            let streamDomain = (value.userInfo["_kCFStreamErrorDomainKey"] as? NSNumber)?.intValue
            let streamCode = (value.userInfo["_kCFStreamErrorCodeKey"] as? NSNumber)?.intValue
            results.append(Self(domain: value.domain, code: value.code, message: value.localizedDescription, sslCode: streamDomain == 3 ? streamCode : nil))
            if let underlying = value.userInfo[NSUnderlyingErrorKey] as? NSError { visit(underlying, depth: depth + 1) }
            if let underlying = value.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError] { for item in underlying.prefix(16) { visit(item, depth: depth + 1) } }
        }
        visit(error as NSError, depth: 0)
        return results
    }
}
struct DiagnosticFailure: Sendable {
    enum Cause: String, Codable, Sendable { case expired, notYetValid, hostname, revoked, untrusted, cleartext, tlsVersion, cipher, keySize, signature, clientCertificate, tlsHandshake, timeout, dns, connection, offline, http, unknown }
    let cause: Cause
    let title: String
    let meaning: String
    let nextStep: String
    let evidence: [ErrorEvidence]
    static func explain(_ record: DiagnosticRecord) -> Self? {
        let evidence = (record.trustErrors ?? []) + (record.networkErrors ?? []) + (record.revocationAssessment?.evidence ?? [])
        let transportEvidence = (record.trustErrors ?? []) + (record.networkErrors ?? [])
        let securityCodes = Set(transportEvidence.filter { $0.domain == NSOSStatusErrorDomain }.map(\.code) + transportEvidence.compactMap(\.sslCode))
        let urlCodes = Set(transportEvidence.filter { $0.domain == NSURLErrorDomain || $0.domain == "kCFErrorDomainCFNetwork" }.map(\.code))
        func make(_ cause: Cause, _ title: String, _ meaning: String, _ next: String) -> Self { Self(cause: cause,title: title,meaning: meaning,nextStep: next,evidence: evidence) }
        if record.revocationAssessment?.status == .revoked || securityCodes.contains(Int(errSecCertificateRevoked)) || securityCodes.contains(Int(errSSLPeerCertRevoked)) {
            return make(.revoked,"Zertifikat widerrufen",record.revocationAssessment?.status == .revoked ? "Die zusätzliche Sperrprüfung bestätigt einen Widerruf. Eine zuvor empfangene HTTP-Antwort oder erfolgreiche Standardprüfung hebt diesen Befund nicht auf." : "Die Zertifikatsprüfung meldet, dass ein Zertifikat dieser Verbindung gesperrt wurde. Die Verbindung wurde nicht akzeptiert.","Der Betreiber muss das gesperrte Zertifikat ersetzen und die Ursache des Widerrufs prüfen.")
        }
        if securityCodes.contains(Int(errSecCertificateExpired)) || urlCodes.contains(URLError.serverCertificateHasBadDate.rawValue) || securityCodes.contains(Int(errSSLCertExpired)) {
            return make(.expired,"Zertifikat abgelaufen","Mindestens ein Zertifikat der geprüften Kette liegt außerhalb seiner Gültigkeit. Eine vertrauenswürdige Verbindung kam nicht zustande.","Gültigkeitsdaten und Gerätezeit prüfen. Der Betreiber muss ein gültiges Zertifikat samt passender Kette bereitstellen.")
        }
        if securityCodes.contains(Int(errSecCertificateNotValidYet)) || urlCodes.contains(URLError.serverCertificateNotYetValid.rawValue) {
            return make(.notYetValid,"Zertifikat noch nicht gültig","Die Gültigkeit eines Zertifikats beginnt erst in der Zukunft.","Gerätezeit und Beginn der Zertifikatsgültigkeit prüfen; der Betreiber muss das richtige Zertifikat verwenden.")
        }
        if securityCodes.contains(Int(errSecHostNameMismatch)) {
            return make(.hostname,"Zertifikat passt nicht zum Hostnamen","Die Zertifikatsprüfung hat eine Abweichung zwischen aufgerufenem Host und den erlaubten Zertifikatsnamen festgestellt.","Adresse und Subject Alternative Names vergleichen. Der Betreiber muss ein Zertifikat für genau diesen Host einsetzen.")
        }
        if urlCodes.contains(URLError.appTransportSecurityRequiresSecureConnection.rawValue) {
            return make(.cleartext,"Unverschlüsseltes HTTP durch ATS blockiert","Die angeforderte URL verwendet HTTP. Die App behält Apples Transport-Schutz bei und sendet diese Anfrage nicht unverschlüsselt.","Eine HTTPS-Adresse verwenden. Dieser Befund beschreibt die App-Richtlinie, nicht einen Fehler des Zertifikats.")
        }
        if securityCodes.contains(Int(errSSLATSMinimumVersionViolation)) || securityCodes.contains(Int(errSSLPeerProtocolVersion)) {
            return make(.tlsVersion,"TLS-Version nicht akzeptiert","Die Systemmeldung benennt eine nicht akzeptierte Protokollversion. Die Verbindung erfüllt die Anforderungen dieses Clients nicht.","Server auf TLS 1.2 oder TLS 1.3 aktualisieren; die einzelnen Versions-Probes können zusätzliche Handshake-Ergebnisse liefern.")
        }
        if securityCodes.contains(Int(errSSLATSCiphersuiteViolation)) || securityCodes.contains(Int(errSSLBadCipherSuite)) {
            return make(.cipher,"Cipher Suite nicht akzeptiert","Die Systemmeldung benennt eine ungeeignete Verschlüsselungskombination.","Moderne Cipher Suites auf dem Server aktivieren. Aus einem einzelnen Verbindungsversuch folgt keine vollständige Liste unterstützter Suites.")
        }
        if securityCodes.contains(Int(errSSLATSMinimumKeySizeViolation)) || securityCodes.contains(Int(errSSLWeakPeerEphemeralDHKey)) {
            return make(.keySize,"Kryptografischer Schlüssel zu schwach","Die Systemmeldung beanstandet die Schlüsselgröße oder den temporären Diffie-Hellman-Schlüssel.","Zertifikatsschlüssel und Schlüsselaustausch des Servers auf zeitgemäße Größen aktualisieren.")
        }
        if securityCodes.contains(Int(errSSLATSLeafCertificateHashAlgorithmViolation)) || securityCodes.contains(Int(errSSLATSCertificateHashAlgorithmViolation)) {
            return make(.signature,"Zertifikatssignatur nicht akzeptiert","Der Signaturalgorithmus erfüllt laut Systemmeldung die Transport-Anforderungen nicht.","Der Betreiber muss eine geeignete Zertifikatskette mit aktuellen Signaturalgorithmen bereitstellen.")
        }
        if urlCodes.contains(URLError.clientCertificateRequired.rawValue) || securityCodes.contains(Int(errSSLCertificateRequired)) || (record.clientCertificateRequested == true && (record.error != nil || (record.status ?? 0) >= 400)) {
            return make(.clientCertificate,"Client-Zertifikat benötigt","Der Server fordert einen Zertifikatsnachweis vom Client an. Für diese Anfrage wurde kein Client-Zertifikat eingerichtet.","Für diesen Dienst ist eine passende Client-Identität erforderlich. Die normale Prüfung des Server-Zertifikats ersetzt diesen Nachweis nicht.")
        }
        if urlCodes.contains(URLError.timedOut.rawValue) { return make(.timeout,"Zeitüberschreitung","Der Server hat innerhalb des Zeitlimits keine vollständige Antwort geliefert. Daraus lässt sich kein bestimmter Zertifikats- oder Cipher-Fehler ableiten.","Netzwerk, Host und Port prüfen und den Test wiederholen. Eine Firewall oder ein nicht verfügbarer Testserver kann denselben Effekt haben.") }
        if urlCodes.contains(URLError.cannotFindHost.rawValue) || urlCodes.contains(URLError.dnsLookupFailed.rawValue) { return make(.dns,"Hostname nicht auflösbar","Für den Host konnte keine erreichbare Adresse ermittelt werden. Die TLS-Prüfung wurde dadurch nicht abgeschlossen.","Schreibweise, DNS und Verfügbarkeit des Hosts prüfen.") }
        if urlCodes.contains(URLError.notConnectedToInternet.rawValue) { return make(.offline,"Keine Netzwerkverbindung","Das System meldet eine fehlende Internetverbindung.","WLAN oder Mobilfunkverbindung prüfen und erneut versuchen.") }
        if urlCodes.contains(URLError.cannotConnectToHost.rawValue) || urlCodes.contains(URLError.networkConnectionLost.rawValue) { return make(.connection,"Serververbindung fehlgeschlagen","Die Verbindung zum Host oder Port konnte nicht aufgebaut oder nicht aufrechterhalten werden. Die Meldung belegt keinen bestimmten Zertifikatsfehler.","Server, Port, Firewall und Netzwerkverbindung prüfen.") }
        if record.trustValid == false || urlCodes.contains(URLError.serverCertificateUntrusted.rawValue) || urlCodes.contains(URLError.serverCertificateHasUnknownRoot.rawValue) {
            return make(.untrusted,"Zertifikatskette nicht vertrauenswürdig","Das System konnte diese Zertifikatskette nicht als vertrauenswürdig bestätigen. Mögliche Gründe sind ein unbekannter Aussteller, eine fehlende Zwischenstelle oder weitere Zertifikatsanforderungen.","Aussteller, vollständige Zertifikatskette und Systemmeldung prüfen. Die App umgeht die Zertifikatsprüfung nicht.")
        }
        if securityCodes.contains(Int(errSSLPeerHandshakeFail)) { return make(.tlsHandshake,"TLS-Peer meldet Handshakefehler","Die Gegenstelle hat den sicheren Verbindungsaufbau mit einem Handshake-Fehler abgelehnt. Der gemeldete Code nennt keinen bestimmten Cipher-, Schlüssel- oder Zertifikatsgrund.","Protokoll- und Serverkonfiguration vergleichen. Das Testziel kann für ein bestimmtes Verfahren eingerichtet sein; das allein beweist noch nicht die konkrete Abbruchursache.") }
        if securityCodes.contains(Int(errSSLIllegalParam)) { return make(.tlsHandshake,"TLS-Parameter nicht akzeptiert","Das System meldet einen unzulässigen TLS-Parameter. Welcher Parameter betroffen ist, wurde in diesem Versuch nicht eindeutig ausgewiesen.","Server-Protokoll und Handshake-Details prüfen. Eine große Zahl von Zertifikatsnamen ist ohne weitere Belege nicht die bestätigte Ursache.") }
        if securityCodes.contains(Int(errSSLClosedNoNotify)) { return make(.tlsHandshake,"TLS-Verbindung ohne Abschluss geschlossen","Die Verbindung wurde ohne den erwarteten TLS-Abschluss beendet. Ein bestimmter Cipher- oder Zertifikatsfehler ist dadurch nicht belegt.","Server, Verbindung und Handshake-Protokoll prüfen und erneut testen.") }
        if urlCodes.contains(URLError.secureConnectionFailed.rawValue) || transportEvidence.contains(where: { $0.sslCode != nil }) {
            return make(.tlsHandshake,"TLS-Verbindung fehlgeschlagen","Der sichere Verbindungsaufbau wurde abgebrochen. Das System hat keine eindeutige Ursache für Protokoll, Cipher, Schlüssel oder Zertifikat bestätigt.","Technische Meldung ansehen und Versions-Probes vergleichen. Nur ein tatsächlich gemeldeter Detailfehler wird als konkrete Ursache ausgewiesen.")
        }
        if let status = record.status, status >= 400 { return make(.http,"Server antwortet mit HTTP \(status)","Der Server ist erreichbar, lehnt die Anfrage aber auf HTTP-Ebene ab. Das ist von der TLS-Zertifikatsprüfung zu unterscheiden.","Antworttext, Pfad, Methode und erforderliche Anmeldung prüfen.") }
        if record.error != nil { return make(.unknown,"Verbindung fehlgeschlagen","Für diesen Fehler ist keine verlässliche genauere Zuordnung verfügbar. Die Originalmeldung bleibt erhalten.","Technische Details prüfen und den Test wiederholen.") }
        return nil
    }
}
