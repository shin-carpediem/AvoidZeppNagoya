import Foundation

struct ZeppEvent: Codable, Identifiable, Hashable {
    let id: String           // e.g. "2026-03-03-UVERworld"
    let performer: String
    let title: String
    let openTime: Date?
    let startTime: Date

    /// 混雑期間（開始側）: startTime ... startTime+30min
    func crowdStartWindow() -> ClosedRange<Date> {
        startTime ... startTime.addingTimeInterval(30 * 60)
    }

    /// 混雑期間（終了側）: endTime ... endTime+30min
    func crowdEndWindow(concertDuration: TimeInterval) -> ClosedRange<Date> {
        let end = startTime.addingTimeInterval(concertDuration)
        return end ... end.addingTimeInterval(30 * 60)
    }

    /// 今この瞬間、混雑しているか
    func isCrowdedNow(concertDuration: TimeInterval) -> Bool {
        let now = Date()
        return crowdStartWindow().contains(now) || crowdEndWindow(concertDuration: concertDuration).contains(now)
    }
}
