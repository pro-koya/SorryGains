import Foundation
import SwiftData
import UserNotifications

/// Manages local notifications with character-voiced messages.
///
/// Schedules contextual notifications based on drinking patterns:
/// - Friday evening reminder
/// - Morning-after prompt
/// - Recovery deadline warning
/// - Sober streak celebration
/// - Session duration alert
@MainActor
final class CharacterNotificationManager {

    static let shared = CharacterNotificationManager()

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule All

    /// Reschedules all recurring notifications based on current data.
    func reschedule(context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        scheduleFridayEvening()
        scheduleMorningAfterIfNeeded(context: context)
        scheduleRecoveryDeadlineIfNeeded(context: context)
        scheduleSoberStreakIfNeeded(context: context)
    }

    // MARK: - Friday Evening

    /// Every Friday at 18:00.
    private func scheduleFridayEvening() {
        let messages = [
            String(localized: "notif.friday.body.1"),
            String(localized: "notif.friday.body.2"),
            String(localized: "notif.friday.body.3"),
            String(localized: "notif.friday.body.4"),
        ]
        let message = messages[dayBasedIndex(messages.count)]

        var dateComponents = DateComponents()
        dateComponents.weekday = 6 // Friday
        dateComponents.hour = 18
        dateComponents.minute = 0

        schedule(
            id: "friday_evening",
            title: String(localized: "notif.title.muscleMessage"),
            body: message,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        )
    }

    // MARK: - Morning After

    /// If the user drank yesterday, notify at 8:00.
    private func scheduleMorningAfterIfNeeded(context: ModelContext) {
        let yesterdayStart = DayBoundary.startOfYesterday()
        let todayStart = DayBoundary.startOfToday()

        let descriptor = FetchDescriptor<DrinkRecord>(
            predicate: #Predicate { record in
                record.timestamp >= yesterdayStart && record.timestamp < todayStart
            }
        )

        guard let count = try? context.fetchCount(descriptor), count > 0 else { return }

        let messages = [
            String(localized: "notif.morning.body.1"),
            String(format: String(localized: "notif.morning.body.2"), count),
            String(localized: "notif.morning.body.3"),
            String(localized: "notif.morning.body.4"),
        ]
        let message = messages[dayBasedIndex(messages.count)]

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        schedule(
            id: "morning_after",
            title: String(localized: "notif.title.muscleMessage"),
            body: message,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )
        )
    }

    // MARK: - Recovery Deadline

    /// If yesterday has pending recovery, warn 2 hours before midnight.
    private func scheduleRecoveryDeadlineIfNeeded(context: ModelContext) {
        let yesterdayStart = DayBoundary.startOfYesterday()
        let todayStart = DayBoundary.startOfToday()

        let drinkDescriptor = FetchDescriptor<DrinkRecord>(
            predicate: #Predicate { record in
                record.timestamp >= yesterdayStart && record.timestamp < todayStart
            }
        )

        guard let drinkCount = try? context.fetchCount(drinkDescriptor), drinkCount > 0 else { return }

        let messages = [
            String(localized: "notif.deadline.body.1"),
            String(localized: "notif.deadline.body.2"),
            String(localized: "notif.deadline.body.3"),
            String(localized: "notif.deadline.body.4"),
        ]
        let message = messages[dayBasedIndex(messages.count)]

        var dateComponents = DateComponents()
        dateComponents.hour = 22
        dateComponents.minute = 0

        schedule(
            id: "recovery_deadline",
            title: String(localized: "notif.title.deadlineNear"),
            body: message,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )
        )
    }

    // MARK: - Sober Streak

    /// If the user hasn't drunk for 3+ days, celebrate.
    private func scheduleSoberStreakIfNeeded(context: ModelContext) {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
        let descriptor = FetchDescriptor<DrinkRecord>(
            predicate: #Predicate { record in
                record.timestamp >= threeDaysAgo
            }
        )

        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }

        let messages = [
            String(localized: "notif.sober.body.1"),
            String(localized: "notif.sober.body.2"),
            String(localized: "notif.sober.body.3"),
            String(localized: "notif.sober.body.4"),
        ]
        let message = messages[dayBasedIndex(messages.count)]

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        schedule(
            id: "sober_streak",
            title: String(localized: "notif.title.muscleHappy"),
            body: message,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )
        )
    }

    // MARK: - Session Duration Alert

    /// Schedule a notification 1 hour into a drinking session.
    func scheduleSessionAlert(sessionStart: Date) {
        let messages = [
            String(localized: "notif.session.body.1"),
            String(localized: "notif.session.body.2"),
            String(localized: "notif.session.body.3"),
        ]
        let message = messages[dayBasedIndex(messages.count)]

        let triggerDate = sessionStart.addingTimeInterval(3600)
        guard triggerDate > .now else { return }

        let interval = triggerDate.timeIntervalSince(.now)
        schedule(
            id: "session_1h",
            title: String(localized: "notif.title.session1h"),
            body: message,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
    }

    /// Remove session-related notifications.
    func cancelSessionAlerts() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["session_1h"])
    }

    // MARK: - Helpers

    private func schedule(
        id: String,
        title: String,
        body: String,
        trigger: UNNotificationTrigger
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func dayBasedIndex(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return day % count
    }
}
