import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct CertificateExport: Transferable {
    let certificate: CertificateRecord
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { $0.certificate.der }.suggestedFileName { $0.certificate.subject + ".der" }
    }
}
struct ToolsView: View {
    @FocusState private var editing: Bool
    @State private var input = ""
    @State private var output = ""
    @State private var operation = "Base64 encode"
    private let operations = ["Base64 encode", "Base64 decode", "URL encode", "URL decode", "Format JSON", "SHA-256", "SHA-512", "Timestamp"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Transform") { Picker("Operation", selection: $operation) { ForEach(operations, id: \.self) { Text($0) } } }
                Section("Input") { TextEditor(text: $input).focused($editing).font(.body.monospaced()).frame(minHeight: 160).accessibilityLabel("Tool input") }
                Button("Transform", systemImage: "arrow.down") { transform() }
                Section("Result") { Text(output).font(.body.monospaced()).textSelection(.enabled); if !output.isEmpty { ShareLink("Share result", item: output) } }
                Section("Privacy") { Text("Diagnostics are stored on this device. Requests connect only to the destination you choose. Exported files may contain credentials or personal data.") }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Tools").toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } }
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
