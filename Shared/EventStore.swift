import Foundation
import Combine

@MainActor
final class EventStore: ObservableObject {
    static let shared = EventStore()

    // MARK: - Published state
    @Published private(set) var events: [ZeppEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastFetch: Date?

    // MARK: - Settings
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    @Published var concertDuration: TimeInterval {
        didSet { UserDefaults.standard.set(concertDuration, forKey: Keys.concertDuration) }
    }

    // MARK: - Init
    private init() {
        let stored = UserDefaults.standard.double(forKey: Keys.concertDuration)
        concertDuration = stored > 0 ? stored : 7200  // default 2h
        notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        events = Self.loadFromDisk()
        lastFetch = UserDefaults.standard.object(forKey: Keys.lastFetch) as? Date
    }

    // MARK: - Refresh
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        do {
            let fetched = try await ScheduleFetcher.shared.fetchEvents()
            events = fetched
            saveToDisk(fetched)
            lastFetch = Date()
            UserDefaults.standard.set(lastFetch, forKey: Keys.lastFetch)

            if notificationsEnabled {
                await NotificationScheduler.shared.scheduleNotifications(
                    for: fetched,
                    concertDuration: concertDuration
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Persistence
    private func saveToDisk(_ events: [ZeppEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: Keys.events)
        }
    }

    private static func loadFromDisk() -> [ZeppEvent] {
        guard let data = UserDefaults.standard.data(forKey: Keys.events),
              let events = try? JSONDecoder().decode([ZeppEvent].self, from: data) else {
            return []
        }
        return events
    }

    // MARK: - Helpers
    var nextCrowdedEvent: ZeppEvent? {
        events.first { $0.startTime > Date() }
    }

    var isStale: Bool {
        guard let lastFetch else { return true }
        return Date().timeIntervalSince(lastFetch) > 3600 * 6  // 6時間で期限切れ
    }

    // MARK: - Keys
    private enum Keys {
        static let events = "zeppEvents"
        static let lastFetch = "zeppLastFetch"
        static let notificationsEnabled = "notificationsEnabled"
        static let concertDuration = "concertDuration"
    }
}
