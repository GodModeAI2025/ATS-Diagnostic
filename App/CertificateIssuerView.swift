import SwiftUI

struct CertificateIssuerView: View {
    let attributes: [CertificateNameAttribute]
    let issuerCertificate: CertificateRecord?
    var body: some View {
        Section("Aussteller dieses Zertifikats") {
            if attributes.isEmpty { Text("Keine auswertbaren Ausstellerangaben verfügbar.").foregroundStyle(.secondary) }
            ForEach(attributes) { attribute in
                VStack(alignment:.leading,spacing:6) { Text(attribute.label).font(.caption.weight(.medium)).foregroundStyle(.secondary);Text(attribute.value).font(.callout).textSelection(.enabled) }.padding(.vertical,3)
            }
            if let issuerCertificate {
                NavigationLink { CertificateDetailView(certificate:issuerCertificate,isLeaf:false,systemCT:nil) } label: {
                    HStack(alignment:.top,spacing:12) { SupportingIllustration(kind:.certificate);VStack(alignment:.leading,spacing:6) { Text(issuerCertificate.subject).font(.subheadline.weight(.semibold));Text("Nächstes Zertifikat der ausgewerteten Kette").font(.caption).foregroundStyle(Color(uiColor:.secondaryLabel)) } }
                }
                Text("Die Angaben oben stammen aus dem Issuer-Feld. Das nächste Kettenzertifikat ist ein eigener Datensatz; die Gesamtaussage zum Vertrauen steht bei der Verbindung.").font(.footnote).foregroundStyle(.secondary)
            } else { Text("Kein weiteres Aussteller-Zertifikat in dieser gespeicherten Kette vorhanden. Gleiche Subject- und Issuer-Namen allein beweisen keine gültige Selbstsignatur.").font(.footnote).foregroundStyle(.secondary) }
        }
    }
}
