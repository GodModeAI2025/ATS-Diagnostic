import SwiftUI

struct DNSLookupView: View {
    @State private var input = ""
    @State private var result: DNSLookupResult?
    @State private var error: String?
    @State private var running = false
    @FocusState private var editing: Bool
    var body: some View {
        Form {
            Section {
                Label("Systemgestützte Adressauflösung", systemImage: "network").font(.headline)
                Text("IPv4- und IPv6-Adressen werden nach den aktuellen Resolver-Einstellungen des Geräts ermittelt.").font(.footnote).foregroundStyle(.secondary)
                TextField("Hostname oder URL", text: $input).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).focused($editing)
                Button("Adressen ermitteln") { lookup() }.disabled(running || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if running { ProgressView("Adressen werden ermittelt…") }
                if let error { Text(error).foregroundStyle(.secondary) }
            }
            if let result {
                Section("Ergebnis") {
                    LabeledContent("Host", value: result.host)
                    LabeledContent("Dauer", value: result.duration.formatted(.number.precision(.fractionLength(3))) + " s")
                    ForEach(result.addresses) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(entry.family.rawValue, systemImage: "network").font(.caption).foregroundStyle(.secondary)
                            Text(entry.address).font(.body.monospaced()).textSelection(.enabled)
                        }
                    }
                    if result.truncated { Text("Die Anzeige ist auf 64 unterschiedliche Adressen begrenzt.").font(.footnote).foregroundStyle(.secondary) }
                    ShareLink("Ergebnis teilen", item: result.text)
                }
            }
        }.navigationTitle("Adressauflösung").scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { editing = false } } }
    }
    private func lookup() {
        editing = false; running = true; result = nil; error = nil
        let target = input
        Task {
            defer { running = false }
            do { result = try await SystemDNSLookup.resolve(target) }
            catch { self.error = error.localizedDescription }
        }
    }
}
