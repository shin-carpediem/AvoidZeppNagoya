import SwiftUI

@main
struct AvoidZeppNagoyaApp: App {
    let store = EventStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    // watchOS は起動時に最新データを取得
                    if store.isStale { await store.refresh() }
                }
        }
    }
}
