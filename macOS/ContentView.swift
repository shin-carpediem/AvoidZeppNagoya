import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var store: EventStore

    private let durationOptions: [(label: String, seconds: TimeInterval)] = [
        ("1.5時間", 5400),
        ("2時間",   7200),
        ("2.5時間", 9000),
        ("3時間",   10800),
    ]

    var body: some View {
        Form {
            // ── 通知設定 ──────────────────────────────────────
            Section("通知設定") {
                Toggle("通知を有効にする", isOn: $store.notificationsEnabled)
                    .onChange(of: store.notificationsEnabled) { _, enabled in
                        guard enabled else { return }
                        Task {
                            let granted = await NotificationScheduler.shared.requestAuthorization()
                            if granted { await store.refresh() }
                        }
                    }
            }

            // ── 公演時間の目安 ────────────────────────────────
            Section("公演時間の目安") {
                Picker("公演時間", selection: $store.concertDuration) {
                    ForEach(durationOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: store.concertDuration) { _, _ in
                    Task { await store.refresh() }
                }
            }

            // ── 更新 ──────────────────────────────────────────
            Section("データ") {
                if store.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("取得中…").foregroundStyle(.secondary)
                    }
                } else {
                    Button("今すぐ更新") { Task { await store.refresh() } }
                }

                if let lastFetch = store.lastFetch {
                    Text("最終更新: \(lastFetch.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let err = store.lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            // ── 直近イベント ──────────────────────────────────
            if !store.events.isEmpty {
                Section("直近のイベント") {
                    ForEach(store.events.prefix(15)) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.performer).fontWeight(.semibold)
                                Text(event.startTime, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if event.isCrowdedNow(concertDuration: store.concertDuration) {
                                Label("混雑中", systemImage: "person.3.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Avoid Zepp Nagoya")
    }
}
