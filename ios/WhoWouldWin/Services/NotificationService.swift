import Foundation
import UserNotifications

/// Schedules an OPTIONAL, parent-enabled daily "come back and play" reminder.
/// Off by default; only ever turned on from the parent-gated Grown-Up Zone.
/// Kid-appropriate: one gentle local notification a day, no marketing, no links.
@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let reminderID = "daily.play.reminder"

    private let messages: [(String, String)] = [
        ("Who would win today? 🦁", "A new Daily Challenge is waiting in Animal Arena!"),
        ("Your animals miss you! 🐯", "Come back for today's battle and mystery sticker."),
        ("New Daily Challenge! ⚔️", "Tap to see today's surprise match-up."),
        ("Mystery sticker time! 🎁", "Open the app to claim today's free sticker."),
    ]

    /// Remove all scheduled reminders (backs the "erase all data" path).
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Ask for permission. Returns whether it was granted. Safe to call repeatedly.
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Turn the daily reminder on (requesting permission) or off. Returns the
    /// effective state (false if permission was refused).
    @discardableResult
    func setDailyReminder(_ enabled: Bool, hour: Int = 17) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard enabled else { return false }

        guard await requestAuthorization() else { return false }

        // Rotate the message by day-of-year so it isn't the same string forever.
        let idx = (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0) % messages.count
        let (title, body) = messages[idx]

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        try? await center.add(request)
        return true
    }
}
