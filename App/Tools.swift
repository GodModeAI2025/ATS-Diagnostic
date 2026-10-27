import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct CertificateExport: Transferable {
    let certificate: CertificateRecord
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { $0.certificate.der }.suggestedFileName { $0.certificate.exportName + ".der" }
    }
}
struct ToolsView: View {
    let store: DiagnosticStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var editing: Bool
    @State private var input = ""
    @State private var output = ""
    @State private var operation = "Base64 encode"
    private let operations = ["Base64 encode", "Base64 decode", "URL encode", "URL decode", "Format JSON", "SHA-256", "SHA-512", "Timestamp"]
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
#if targetEnvironment(macCatalyst)
                MacToolsWorkspace(input: $input, operation: $operation, output: output, operations: operations, width: geometry.size.width) {
                    editing = false
                    transform()
                }
#else
                if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        HStack(alignment: .top, spacing: 24) {
                            DiagnosticPanel(title: "Input", illustration: .traffic) { NavigationLink("Adressauflösung") { DNSLookupView() }; operationPicker; inputEditor; transformButton }.frame(maxWidth: 520)
                            VStack(spacing: 20) {
                                DiagnosticPanel(title: "Result", illustration: .traffic) { resultContent }
                                DiagnosticPanel(title: "Privacy", illustration: .certificate) { privacyText }
                            }.frame(maxWidth: 600)
                        }.padding(24).frame(maxWidth: .infinity)
                    }.background(Color(uiColor: .systemGroupedBackground))
                } else {
                    Form {
                        Section { NavigationLink { DNSLookupView() } label: { Label("Adressauflösung", systemImage: "network") } }
                        Section("Transform") { operationPicker }
                        Section("Input") { inputEditor }
                        transformButton
                        Section("Result") { resultContent }
                        Section("Privacy") { privacyText }
                    }
                }
#endif
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Tools").toolbar {
                ToolbarItem(placement: .topBarTrailing) { NavigationLink { DiagnosticSettingsView(store:store) } label: { Label("Diagnoseeinstellungen",systemImage:"slider.horizontal.3") } }
                ToolbarItemGroup(placement: .keyboard) { if editing { Spacer(); Button("Done") { editing = false } } }
            }.onDisappear { editing = false }
        }
    }
    private var operationPicker: some View { Picker("Operation", selection: $operation) { ForEach(operations, id: \.self) { Text(LocalizedStringKey($0)) } } }
    private var inputEditor: some View { TextEditor(text: $input).focused($editing).font(.body.monospaced()).frame(minHeight: 180).accessibilityLabel("Tool input") }
    private var transformButton: some View { Button { editing = false; transform() } label: { Label("Transform", systemImage: "arrow.down").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.diagnosticAction).foregroundStyle(.white).controlSize(.large) }
    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if output.isEmpty { Text("Choose an operation and transform your input.").foregroundStyle(.secondary) }
            else { Text(output).font(.body.monospaced()).textSelection(.enabled); ShareLink("Share result", item: output) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var privacyText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics are stored on this device. Requests connect only to the destination you choose. Exported files may contain credentials or personal data.").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Link("Datenschutzerklärung / Privacy Policy", destination: URL(string: "https://www.mobilebox-consulting.de/datenschutzerklärung-privacy-policy/")!)
        }
    }
    private func transform() {
        let data = Data(input.utf8)
        switch operation {
        case "Base64 encode": output = data.base64EncodedString()
        case "Base64 decode": output = Data(base64Encoded: input).flatMap { String(data: $0, encoding: .utf8) } ?? "Enter valid Base64 containing UTF-8 text."
        case "URL encode": output = input.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "Unable to encode input."
        case "URL decode": output = input.removingPercentEncoding ?? "Enter a valid percent-encoded string."
        case "Format JSON":
            do { let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]); output = String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]), as: UTF8.self) }
            catch { output = error.localizedDescription }
        case "SHA-256": output = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case "SHA-512": output = SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
        default:
            if let seconds = Double(input) { output = Date(timeIntervalSince1970: seconds).formatted(date: .complete, time: .complete) }
            else { output = "Enter Unix time in seconds." }
        }
    }
}

#if targetEnvironment(macCatalyst)
private struct MacToolsWorkspace: View {
    @Binding var input: String
    @Binding var operation: String
    let output: String
    let operations: [String]
    let width: CGFloat
    let transform: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Picker("Operation", selection: $operation) { ForEach(operations, id: \.self) { Text(LocalizedStringKey($0)) } }
                            .frame(maxWidth: 320)
                        Button("Transform", systemImage: "arrow.right", action: transform)
                            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle).controlSize(.regular).tint(.diagnosticAction).foregroundStyle(.white)
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Operation", selection: $operation) { ForEach(operations, id: \.self) { Text(LocalizedStringKey($0)) } }
                        Button("Transform", systemImage: "arrow.down", action: transform)
                            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle).controlSize(.regular).tint(.diagnosticAction).foregroundStyle(.white)
                    }
                }
                Divider()
                let columns = width >= 720 && !dynamicTypeSize.isAccessibilitySize
                let layout = columns ? AnyLayout(HStackLayout(alignment: .top, spacing: 24)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
                layout {
                    MacToolInput(input: $input)
                    MacToolOutput(output: output)
                }
                Divider()
                NavigationLink { DNSLookupView() } label: { Label("Adressauflösung", systemImage: "network") }
                DisclosureGroup("Privacy") {
                    Text("Diagnostics are stored on this device. Requests connect only to the destination you choose. Exported files may contain credentials or personal data.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("Datenschutzerklärung / Privacy Policy", destination: URL(string: "https://www.mobilebox-consulting.de/datenschutzerklärung-privacy-policy/")!)
                        .font(.footnote)
                }.font(.footnote).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color(uiColor: .systemBackground))
    }
}

private struct MacToolInput: View {
    @Binding var input: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Input").font(.headline)
            MacTechnicalTextEditor(text: $input, accessibilityName: String(localized: "Tool input"))
                .padding(8).frame(minHeight: 300).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1)))
                .accessibilityLabel("Tool input")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MacToolOutput: View {
    let output: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Result").font(.headline)
                Spacer()
                if !output.isEmpty { ShareLink(item: output) { Label("Share result", systemImage: "square.and.arrow.up") }.labelStyle(.iconOnly) }
            }
            ScrollView([.horizontal, .vertical]) {
                Text(output.isEmpty ? String(localized: "Choose an operation and transform your input.") : output)
                    .font(.callout.monospaced()).foregroundStyle(output.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(12)
            }.frame(minHeight: 300).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1)))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
