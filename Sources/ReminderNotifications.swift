import Foundation
import UserNotifications
import UIKit

/// Local-only reminder helpers for PandaPlate.
/// No remote push. No calorie targets or weigh-in guilt. Session preference drives schedule;
/// delivery is best-effort on-device (Clear-style honesty — not a guarantee).
enum ReminderNotifications {
    static let idMorning = "pandaplate.reminder.morning"
    static let idMealFirst = "pandaplate.reminder.meal.first"
    static let idMealMidday = "pandaplate.reminder.meal.midday"
    static let idMealEvening = "pandaplate.reminder.meal.evening"
    static let idPipHungry = "pandaplate.reminder.pip.hungry"

    static var allIdentifiers: [String] {
        [idMorning, idMealFirst, idMealMidday, idMealEvening, idPipHungry]
    }

    /// Preferences that should trigger the system permission prompt and scheduling.
    static func shouldRequest(for preference: String?) -> Bool {
        guard let preference else { return false }
        return preference != "Set up later"
    }

    @MainActor
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Requests alert/sound/badge on the main actor. Returns whether the user granted access.
    @MainActor
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIdentifiers)
    }

    /// Cancel prior PandaPlate reminder IDs, then schedule matching `preference` when authorized.
    @MainActor
    static func reschedule(
        preference: String?,
        firstMealTime: String,
        companionName: String
    ) async {
        cancelAll()
        guard shouldRequest(for: preference), let preference else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let pet = sanitizedCompanionName(companionName)
        switch preference {
        case "In the morning":
            await addDaily(
                id: idMorning,
                hour: 8,
                minute: 0,
                title: "Morning check-in",
                body: "A gentle nudge to log breakfast or say hi to \(pet) when you’re ready."
            )
        case "Before each meal":
            if let first = parseHourMinute(firstMealTime) {
                await addDaily(
                    id: idMealFirst,
                    hour: first.hour,
                    minute: first.minute,
                    title: "Meal log nudge",
                    body: "If it helps, log your meal when you’re ready — no pressure."
                )
                // A second gentle evening nudge so “each meal” isn’t only once.
                await addDaily(
                    id: idMealEvening,
                    hour: 18,
                    minute: 0,
                    title: "Evening meal nudge",
                    body: "Optional reminder to log dinner with \(pet) nearby."
                )
            } else {
                await addDaily(
                    id: idMealMidday,
                    hour: 12,
                    minute: 0,
                    title: "Midday meal nudge",
                    body: "If it helps, log lunch when you’re ready — no pressure."
                )
                await addDaily(
                    id: idMealEvening,
                    hour: 18,
                    minute: 0,
                    title: "Evening meal nudge",
                    body: "Optional reminder to log dinner with \(pet) nearby."
                )
            }
        case "When Pip is hungry":
            await addDaily(
                id: idPipHungry,
                hour: 15,
                minute: 0,
                title: "\(pet) is a little hungry",
                body: "\(pet) peeked over — a soft nudge to check in or log something when you like."
            )
        default:
            break
        }
    }

    // MARK: - Private

    private static func sanitizedCompanionName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pip" : String(trimmed.prefix(24))
    }

    private static func parseHourMinute(_ value: String) -> (hour: Int, minute: Int)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), (0...23).contains(hour),
              let minute = Int(parts[1]), (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    @MainActor
    private static func addDaily(
        id: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Best-effort local schedule — leave pending empty rather than crash.
        }
    }
}
