import Foundation
import UserNotifications
import SwiftUI

extension CertificateRecord {
    var expiryDate: Date? {
        guard let value = (try? X509.fields(der))?.first(where: { $0.id == "until" })?.value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
enum CertificateReminderPlan {
    enum PlanError: LocalizedError {
        case expired, invalidDate, notificationsDenied
        var errorDescription: String? {
            switch self {
            case .expired: "This certificate has expired or expires within the next minute."
            case .invalidDate: "Choose a future reminder time before the certificate expires."
            case .notificationsDenied: "Notifications are disabled. You can enable them in system Settings."
            }
        }
    }
    static func suggestedDate(expiry: Date, now: Date = Date()) throws -> Date {
        guard expiry > now.addingTimeInterval(60) else { throw PlanError.expired }
        return max(now.addingTimeInterval(60), expiry.addingTimeInterval(-7 * 24 * 60 * 60))
    }
    static func validate(date: Date, expiry: Date, now: Date = Date()) throws {
        guard date > now, date < expiry else { throw PlanError.invalidDate }
    }
    static func identifier(_ certificate: CertificateRecord) -> String { "certificate-expiry-" + certificate.id }
}
@MainActor enum CertificateReminders {
    static func schedule(certificate: CertificateRecord, date: Date, includeSubject: Bool) async throws {
        guard let expiry = certificate.expiryDate else { throw CertificateReminderPlan.PlanError.invalidDate }
        try CertificateReminderPlan.validate(date: date, expiry: expiry)
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw CertificateReminderPlan.PlanError.notificationsDenied }
        let category = UNNotificationCategory(identifier: "certificate-expiry", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: String(localized: "Certificate expiry reminder"), options: [])
        center.setNotificationCategories([category])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Certificate expiry")
        let formattedExpiry = expiry.formatted(date: .abbreviated, time: .shortened)
        content.body = includeSubject ? String(localized: "The certificate for \(certificate.subject) expires on \(formattedExpiry).") : String(localized: "A certificate you inspected expires on \(formattedExpiry).")
        content.sound = .default
        content.categoryIdentifier = category.identifier
        content.threadIdentifier = "certificate-expiry"
        content.userInfo = ["certificateID": certificate.id]
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.timeZone = TimeZone.current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: CertificateReminderPlan.identifier(certificate), content: content, trigger: trigger))
    }
    static func pendingDate(certificate: CertificateRecord) async -> Date? {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let trigger = requests.first(where: { $0.identifier == CertificateReminderPlan.identifier(certificate) })?.trigger as? UNCalendarNotificationTrigger
        return trigger?.nextTriggerDate()
    }
    static func remove(certificate: CertificateRecord) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [CertificateReminderPlan.identifier(certificate)])
    }
}
struct CertificateReminderView: View {
    let certificate: CertificateRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedDate = Date().addingTimeInterval(3600)
    @State private var includeSubject = false
    @State private var existingDate: Date?
    @State private var error: String?
    @State private var saving = false
    @State private var notificationsDenied = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IllustratedSectionTitle(title: "Certificate expiry", kind: .certificate)
                    Text(certificate.subject).font(.headline)
                    if let expiry = certificate.expiryDate { LabeledContent("Expires", value: expiry.formatted(date: .abbreviated, time: .shortened)) }
                }
                Section("Reminder") {
                    DatePicker("Remind me", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Include certificate subject", isOn: $includeSubject)
                    Text("The subject can appear on your Lock Screen when notification previews are enabled. Reminders are scheduled locally on this device.").font(.footnote).foregroundStyle(.secondary)
                    Button("Save reminder", systemImage: "bell.badge") {
                        Task {
                            saving = true; defer { saving = false }
                            do { try await CertificateReminders.schedule(certificate: certificate, date: selectedDate, includeSubject: includeSubject); dismiss() }
                            catch { self.error = error.localizedDescription; if let planError = error as? CertificateReminderPlan.PlanError, case .notificationsDenied = planError { notificationsDenied = true } }
                        }
                    }.disabled(saving)
                }
                if let existingDate {
                    Section("Scheduled reminder") {
                        Text(existingDate, format: .dateTime.month().day().hour().minute())
                        Button("Remove reminder", role: .destructive) { CertificateReminders.remove(certificate: certificate); self.existingDate = nil }
                    }
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                        if notificationsDenied {
                            Button("Open notification settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        }
                    }
                }
            }.navigationTitle("Expiry reminder").toolbar { Button("Done") { dismiss() } }
                .task {
                    if let expiry = certificate.expiryDate { do { selectedDate = try CertificateReminderPlan.suggestedDate(expiry: expiry) } catch { self.error = error.localizedDescription } }
                    existingDate = await CertificateReminders.pendingDate(certificate: certificate)
                    if let existingDate { selectedDate = existingDate }
                }
        }
    }
}

final class CertificateNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
