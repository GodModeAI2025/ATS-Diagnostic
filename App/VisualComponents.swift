import SwiftUI

extension Color {
    static var diagnosticAccent: Color { Color("AccentColor") }
    static var diagnosticTint: Color { Color("DiagnosticTint") }
}
struct InspectionHero: View {
    let record: DiagnosticRecord?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection intelligence").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text("See what’s behind\nyour connection.").font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                SupportingIllustration(kind: .server)
            }
            HStack(spacing: 0) {
                ConnectionStep(title: "Endpoint", symbol: "globe", active: record != nil)
                Rectangle().fill(Color.secondary.opacity(0.18)).frame(width: 18, height: 1).accessibilityHidden(true)
                ConnectionStep(title: "TLS & trust", symbol: "lock.shield", active: record?.trustValid == true)
                Rectangle().fill(Color.secondary.opacity(0.18)).frame(width: 18, height: 1).accessibilityHidden(true)
                ConnectionStep(title: "Response", symbol: "arrow.down.doc", active: record?.status != nil)
            }
            Text("Certificates, security and timings — measured on your device.").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 12)
    }
}
private struct ConnectionStep: View {
    let title: LocalizedStringResource
    let symbol: String
    let active: Bool
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.title3).foregroundStyle(active ? Color.diagnosticAccent : Color.secondary).frame(width: 44, height: 44).background(active ? Color.diagnosticTint : Color.secondary.opacity(0.06), in: Circle())
            Text(title).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}
struct MetricTile: View {
    let title: LocalizedStringResource
    let value: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SupportingIllustration(kind: symbol == "timer" ? .timing : symbol == "checkmark.seal" || symbol == "lock" ? .certificate : .traffic)
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(Color.diagnosticAccent) }.font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).fixedSize(horizontal: false, vertical: true)
        }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(Color.diagnosticTint.opacity(0.55), in: RoundedRectangle(cornerRadius: 18)).accessibilityElement(children: .combine)
    }
}
struct ConnectionOverview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let record: DiagnosticRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(record.error == nil ? "Connection received" : "Connection needs attention", systemImage: record.error == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").font(.headline).foregroundStyle(record.error == nil ? Color.diagnosticAccent : Color.orange)
                Spacer()
            }
            AdaptiveMetricGrid {
                MetricTile(title: "HTTP status", value: record.status.map(String.init) ?? "Failed", symbol: "arrow.down.circle")
                MetricTile(title: "TLS version", value: tlsName(record.tlsVersion), symbol: "lock")
                MetricTile(title: "Duration", value: record.duration.formatted(.number.precision(.fractionLength(3))) + " s", symbol: "timer")
                MetricTile(title: "Certificates", value: record.certificates.count.formatted(), symbol: "checkmark.seal")
            }
        }.padding(.vertical, 8)
    }
    private func tlsName(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "0x0304": "TLS 1.3"
        case "0x0303": "TLS 1.2"
        case "0x0302": "TLS 1.1"
        case "0x0301": "TLS 1.0"
        default: raw ?? "Not reported"
        }
    }
}
struct TrafficOverview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let statistics: TrafficStatistics
    var body: some View {
        AdaptiveMetricGrid {
            MetricTile(title: "Requests", value: statistics.count.formatted(), symbol: "arrow.up.arrow.down")
            MetricTile(title: "Response data", value: statistics.bytes.formatted(.byteCount(style: .file)), symbol: "externaldrive")
            MetricTile(title: "Average time", value: statistics.averageDuration.formatted(.number.precision(.fractionLength(3))) + " s", symbol: "timer")
            MetricTile(title: "Failures", value: statistics.failures.formatted(), symbol: "exclamationmark.circle")
        }.padding(.vertical, 8)
    }
}
struct ConnectionTimingChart: View {
    let record: DiagnosticRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let duration = record.dnsDuration { TimingBar(title: "DNS lookup", duration: duration, total: record.duration, symbol: "globe") }
            if let duration = record.connectDuration { TimingBar(title: "Connection", duration: duration, total: record.duration, symbol: "link") }
            if let duration = record.tlsDuration { TimingBar(title: "TLS handshake", duration: duration, total: record.duration, symbol: "lock") }
            Text("Each bar compares a measured phase with total request time. Phases can overlap.").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
    }
}
private struct TimingBar: View {
    let title: LocalizedStringResource
    let duration: Double
    let total: Double
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack { Label { Text(title) } icon: { Image(systemName: symbol) }; Spacer(); Text(duration.formatted(.number.precision(.fractionLength(3))) + " s").monospacedDigit() }
                VStack(alignment: .leading) { Label { Text(title) } icon: { Image(systemName: symbol) }; Text(duration.formatted(.number.precision(.fractionLength(3))) + " s").monospacedDigit() }
            }.font(.subheadline)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.diagnosticTint)
                    Capsule().fill(Color.diagnosticAccent.opacity(0.65)).frame(width: max(3, proxy.size.width * min(1, max(0, total > 0 ? duration / total : 0))))
                }
            }.frame(height: 8).accessibilityHidden(true)
        }.accessibilityElement(children: .combine)
    }
}

enum IllustrationKind: String { case server, certificate, timing, traffic }
struct SupportingIllustration: View {
    let kind: IllustrationKind
    @ScaledMetric(relativeTo: .body) private var side = 36.0
    var body: some View {
        Image("Illustration-" + kind.rawValue).resizable().scaledToFit().frame(width: side, height: side).accessibilityHidden(true)
    }
}
struct IllustratedSectionTitle: View {
    let title: LocalizedStringResource
    let kind: IllustrationKind
    var body: some View {
        HStack(spacing: 10) { SupportingIllustration(kind: kind); Text(title).font(.headline) }
    }
}

struct AdaptiveMetricGrid<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: () -> Content
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { content() }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) { content() }
            }
        }
    }
}
struct DiagnosticPanel<Content: View>: View {
    let title: LocalizedStringResource
    let illustration: IllustrationKind
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            IllustratedSectionTitle(title: title, kind: illustration)
            content()
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
