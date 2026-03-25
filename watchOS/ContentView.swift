import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: EventStore

    var body: some View {
        NavigationStack {
            if store.isLoading {
                ProgressView("取得中…")
            } else if store.events.isEmpty {
                Label("イベントなし", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                eventList
            }
        }
        .navigationTitle("Avoid Zepp")
    }

    private var eventList: some View {
        List {
            ForEach(store.events.prefix(5)) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.performer)
                        .font(.headline)
                        .lineLimit(1)

                    Text(event.startTime, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // 混雑中インジケーター
                    if event.isCrowdedNow(concertDuration: store.concertDuration) {
                        Label("混雑中", systemImage: "person.3.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else {
                        // 次の混雑開始までのカウントダウン
                        let remaining = event.startTime.timeIntervalSinceNow
                        if remaining > 0 {
                            Text("混雑まで \(formatInterval(remaining))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let mins  = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)時間\(mins)分" }
        return "\(mins)分"
    }
}
