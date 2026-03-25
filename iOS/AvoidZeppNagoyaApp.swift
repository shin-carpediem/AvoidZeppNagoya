import SwiftUI
import BackgroundTasks

@main
struct AvoidZeppNagoyaApp: App {
    let store = EventStore.shared
    private let refreshTaskID = "com.avoidzeppnagoya.refresh"

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await EventStore.shared.refresh()
                task.setTaskCompleted(success: EventStore.shared.lastError == nil)
                // 次回バックグラウンドリフレッシュをスケジュール
                let req = BGAppRefreshTaskRequest(identifier: "com.avoidzeppnagoya.refresh")
                req.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
                try? BGTaskScheduler.shared.submit(req)
            }
            task.expirationHandler = { task.setTaskCompleted(success: false) }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    if store.isStale { await store.refresh() }
                }
        }
    }

}
