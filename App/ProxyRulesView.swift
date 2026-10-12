import SwiftUI

struct ProxyRulesView: View {
    let monitor: ProxyMonitor
    @State private var draft: ProxyRuleConfiguration?
    var body: some View {
        List {
            Section {
                Text("Regeln gelten für genau die angegebene URL. Bei mehreren Treffern wird die erste Regel verwendet. Änderungen sind nur bei gestopptem Proxy möglich.").font(.footnote).foregroundStyle(.secondary)
                Text("Regeln bleiben für diese App-Sitzung erhalten. CONNECT-Tunnel und Upgrade-Verbindungen werden nicht verändert. Bei einem Zielwechsel entfallen alte Authorization- und Cookie-Header.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Regeln · \(monitor.rewriteConfigurations.count)") {
                ForEach(monitor.rewriteConfigurations) { configuration in
                    Button { draft = configuration } label: {
                        HStack {
                            Image(systemName: configuration.enabled ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.diagnosticAccent)
                            VStack(alignment: .leading) {
                                Text(configuration.matchURL).font(.callout).lineLimit(2)
                                Text(configuration.replacementURL.isEmpty ? "Ziel unverändert" : configuration.replacementURL).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }.disabled(monitor.running).deleteDisabled(monitor.running).moveDisabled(monitor.running)
                }.onDelete { monitor.removeRewriteConfigurations(at: $0) }
                .onMove { monitor.moveRewriteConfigurations(from: $0, to: $1) }
            }.disabled(monitor.running)
            Button("Regel hinzufügen", systemImage: "plus") { draft = ProxyRuleConfiguration() }.disabled(monitor.running || monitor.rewriteConfigurations.count >= 64)
        }.navigationTitle("Proxy-Regeln")
            .toolbar { EditButton().disabled(monitor.running) }
            .sheet(item: $draft) { configuration in
                ProxyRuleEditor(configuration: configuration) { value in
                    try monitor.saveRewriteConfiguration(value)
                }
            }
    }
}
private struct ProxyRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration: ProxyRuleConfiguration
    @State private var error: String?
    let save: (ProxyRuleConfiguration) throws -> Void
    init(configuration: ProxyRuleConfiguration, save: @escaping (ProxyRuleConfiguration) throws -> Void) {
        _configuration = State(initialValue: configuration); self.save = save
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Treffer") {
                    Toggle("Aktiviert", isOn: $configuration.enabled)
                    TextField("Exakte HTTP- oder HTTPS-URL", text: $configuration.matchURL).keyboardType(.URL)
                }
                Section("Änderungen") {
                    TextField("Neues Ziel · optional", text: $configuration.replacementURL).keyboardType(.URL)
                    TextField("Neue Methode · optional", text: $configuration.method)
                    TextEditor(text: $configuration.headerText).font(.body.monospaced()).frame(minHeight: 100).accessibilityLabel("Neue Header")
                    Text("Header als Name: Wert. Leere Felder lassen bestehende Werte unverändert.").font(.footnote).foregroundStyle(.secondary)
                    Picker("Body", selection: $configuration.bodyMode) {
                        ForEach(ProxyRuleConfiguration.BodyMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                    }
                    if configuration.bodyMode != .unchanged {
                        TextEditor(text: $configuration.bodyText).font(.body.monospaced()).frame(minHeight: 140).accessibilityLabel("Neuer Body")
                        Text("Ein leerer neuer Body ersetzt den bisherigen Inhalt durch null Bytes.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.textInputAutocapitalization(.never).autocorrectionDisabled().scrollDismissesKeyboard(.interactively)
                .navigationTitle("Regel bearbeiten")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Sichern") {
                        do { _ = try configuration.rule(); try save(configuration); dismiss() }
                        catch { self.error = error.localizedDescription }
                    } }
                }
        }
    }
}
