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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var editing: Bool
    @State private var input = ""
    @State private var output = ""
    @State private var operation = "Base64 encode"
    private let operations = ["Base64 encode", "Base64 decode", "URL encode", "URL decode", "Format JSON", "SHA-256", "SHA-512", "Timestamp"]
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        HStack(alignment: .top, spacing: 24) {
                            DiagnosticPanel(title: "Input", illustration: .traffic) { operationPicker; inputEditor; transformButton }.frame(maxWidth: 520)
                            VStack(spacing: 20) {
                                DiagnosticPanel(title: "Result", illustration: .traffic) { resultContent }
                                DiagnosticPanel(title: "Privacy", illustration: .certificate) { privacyText }
                            }.frame(maxWidth: 600)
                        }.padding(24).frame(maxWidth: .infinity)
                    }.background(Color(uiColor: .systemGroupedBackground))
                } else {
                    Form {
                        Section("Transform") { operationPicker }
                        Section("Input") { inputEditor }
                        transformButton
                        Section("Result") { resultContent }
                        Section("Privacy") { privacyText }
                    }
                }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Tools").toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } }
        }
    }
    private var operationPicker: some View { Picker("Operation", selection: $operation) { ForEach(operations, id: \.self) { Text($0) } } }
    private var inputEditor: some View { TextEditor(text: $input).focused($editing).font(.body.monospaced()).frame(minHeight: 180).accessibilityLabel("Tool input") }
    private var transformButton: some View { Button { editing = false; transform() } label: { Label("Transform", systemImage: "arrow.down").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large) }
    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if output.isEmpty { Text("Choose an operation and transform your input.").foregroundStyle(.secondary) }
            else { Text(output).font(.body.monospaced()).textSelection(.enabled); ShareLink("Share result", item: output) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var privacyText: some View { Text("Diagnostics are stored on this device. Requests connect only to the destination you choose. Exported files may contain credentials or personal data.").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
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
