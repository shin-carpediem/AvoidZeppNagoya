import Foundation
import UserNotifications

struct NotificationScheduler {
    static let shared = NotificationScheduler()

    /// iOS/macOS/watchOS での最大保留通知数を考慮（iOS: 64）
    private let maxEvents = 16  // 16 events × 4 notifications = 64

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleNotifications(for events: [ZeppEvent], concertDuration: TimeInterval) async {
        let center = UNUserNotificationCenter.current()

        // 既存の Zepp 通知をすべて削除
        let pending = await center.pendingNotificationRequests()
        let zeppIds = pending.filter { $0.identifier.hasPrefix("zepp-") }.map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: zeppIds)

        // 直近 maxEvents 件のみ対象
        let upcoming = events
            .filter { $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
            .prefix(maxEvents)

        for event in upcoming {
            await schedule(event: event, concertDuration: concertDuration, center: center)
        }
    }

    // MARK: - Private

    private func schedule(event: ZeppEvent, concertDuration: TimeInterval, center: UNUserNotificationCenter) async {
        let now = Date()
        let endTime = event.startTime.addingTimeInterval(concertDuration)

        let notifications: [(suffix: String, date: Date, title: String, body: String)] = [
            ("start",       event.startTime,                               "🔴 Zepp Nagoya 混雑中",  "\(event.performer) 開場"),
            ("start-clear", event.startTime.addingTimeInterval(30 * 60),   "🟢 Zepp Nagoya 混雑解消", "混雑が落ち着きました"),
            ("end",         endTime,                                        "🔴 Zepp Nagoya 混雑中",  "\(event.performer) 終演"),
            ("end-clear",   endTime.addingTimeInterval(30 * 60),           "🟢 Zepp Nagoya 混雑解消", "混雑が落ち着きました"),
        ]

        for n in notifications {
            guard n.date > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = n.title
            content.body  = n.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: n.date
                ),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "zepp-\(event.id)-\(n.suffix)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("[NotificationScheduler] Failed to add: \(error)")
            }
        }
    }
}
