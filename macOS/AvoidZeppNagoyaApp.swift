import SwiftUI

@main
struct AvoidZeppNagoyaApp: App {
    let store = EventStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    if store.isStale { await store.refresh() }
                }
                .frame(minWidth: 400, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("今すぐ更新") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
