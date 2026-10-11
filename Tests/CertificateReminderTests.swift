import Foundation
import Testing
@testable import ATSDiagnostic
struct CertificateReminderTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    @Test func defaultIsOneWeekBeforeExpiry() throws {
        let expiry = now.addingTimeInterval(30 * 86400)
        #expect(try CertificateReminderPlan.suggestedDate(expiry: expiry, now: now) == expiry.addingTimeInterval(-7 * 86400))
    }
    @Test func soonExpirySchedulesFutureReminder() throws { #expect(try CertificateReminderPlan.suggestedDate(expiry: now.addingTimeInterval(3600), now: now) == now.addingTimeInterval(60)) }
    @Test func refusesExpiredCertificate() { #expect(throws: CertificateReminderPlan.PlanError.self) { try CertificateReminderPlan.suggestedDate(expiry: now.addingTimeInterval(-1), now: now) } }
    @Test func refusesReminderAfterExpiry() { #expect(throws: CertificateReminderPlan.PlanError.self) { try CertificateReminderPlan.validate(date: now.addingTimeInterval(7200), expiry: now.addingTimeInterval(3600), now: now) } }
    @Test func replacementIdentifierIsStable() { let certificate = CertificateRecord(id: "1234", subject: "example.com", der: Data()); #expect(CertificateReminderPlan.identifier(certificate) == "certificate-expiry-1234") }
}
