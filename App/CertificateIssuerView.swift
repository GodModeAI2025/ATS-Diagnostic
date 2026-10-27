import SwiftUI

struct CertificateIssuerView: View {
    let attributes: [CertificateNameAttribute]
    let issuerCertificate: CertificateRecord?
    var body: some View {
        Section("Certificate issuer") {
            if attributes.isEmpty { Text("No readable issuer details are available.").foregroundStyle(.secondary) }
            ForEach(attributes) { attribute in
                VStack(alignment:.leading,spacing:6) { Text(LocalizedStringKey(displayLabel(for: attribute))).font(.caption.weight(.medium)).foregroundStyle(.secondary);Text(attribute.value).font(.callout).textSelection(.enabled) }.padding(.vertical,3)
            }
            if let issuerCertificate {
                NavigationLink { CertificateDetailView(certificate:issuerCertificate,isLeaf:false,systemCT:nil) } label: {
                    HStack(alignment:.top,spacing:12) { SupportingIllustration(kind:.certificate);VStack(alignment:.leading,spacing:6) { Text(issuerCertificate.subject).font(.subheadline.weight(.semibold));Text("Next certificate in the evaluated chain").font(.caption).foregroundStyle(Color(uiColor:.secondaryLabel)) } }
                }
                Text("The details above come from the issuer field. The next chain certificate is a separate record; the overall trust result appears with the connection.").font(.footnote).foregroundStyle(.secondary)
            } else { Text("No further issuer certificate is present in this saved chain. Matching subject and issuer names alone do not prove a valid self-signature.").font(.footnote).foregroundStyle(.secondary) }
        }
    }
    private func displayLabel(for attribute: CertificateNameAttribute) -> String {
        ["2.5.4.3": "Name (CN)", "2.5.4.10": "Organization (O)", "2.5.4.11": "Organizational unit (OU)", "2.5.4.6": "Country (C)", "2.5.4.7": "City (L)", "2.5.4.8": "Region (ST)", "2.5.4.5": "Serial identifier", "2.5.4.9": "Street", "2.5.4.17": "Postal code", "1.2.840.113549.1.9.1": "Email"][attribute.oid] ?? attribute.oid
    }
}
