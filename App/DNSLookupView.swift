import SwiftUI

struct DNSLookupView: View {
    @State private var input = ""
    @State private var result: DNSLookupResult?
    @State private var reverseResult: DNSReverseResult?
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
                Button("Hostname zur IP ermitteln") { reverseLookup() }.disabled(running || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if running { ProgressView("Systemresolver wird abgefragt…") }
                if let error { Text(error).foregroundStyle(.secondary) }
            }
            if let reverseResult {
                ReverseDNSResultSection(result: reverseResult)
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
    private func reverseLookup() {
        editing = false; running = true; result = nil; reverseResult = nil; error = nil
        let target = input
        Task {
            defer { running = false }
            do { reverseResult = try await SystemReverseDNSLookup.resolve(target) }
            catch let failure as URLError where failure.code == .badURL {
                error = "Gib für die Rückwärtsauflösung eine IPv4- oder IPv6-Adresse ein, ohne URL oder Port."
            } catch { self.error = error.localizedDescription }
        }
    }
    private func lookup() {
        editing = false; running = true; result = nil; reverseResult = nil; error = nil
        let target = input
        Task {
            defer { running = false }
            do { result = try await SystemDNSLookup.resolve(target) }
            catch { self.error = error.localizedDescription }
        }
    }
}


private struct ReverseDNSResultSection: View {
    let result: DNSReverseResult
    var body: some View {
        Section("Rückwärtsauflösung") {
            Label("Gemeldeter Hostname", systemImage: "arrow.uturn.backward").font(.caption).foregroundStyle(.secondary)
            Text(result.hostname).textSelection(.enabled)
            Text(result.address).font(.body.monospaced()).textSelection(.enabled)
            LabeledContent("Dauer", value: result.duration.formatted(.number.precision(.fractionLength(3))) + " s")
            Text("Die Antwort stammt aus dem Systemresolver. Sie bestätigt weder die Identität des Servers noch sein Zertifikatsvertrauen; lokale Namensquellen können beteiligt sein.").font(.footnote).foregroundStyle(.secondary)
            ShareLink("Ergebnis teilen", item: result.text)
        }
    }
}
