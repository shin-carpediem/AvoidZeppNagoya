import Foundation
import SwiftSoup

actor ScheduleFetcher {
    static let shared = ScheduleFetcher()

    private let baseURL = "https://www.zepp.co.jp/hall/nagoya/schedule/"
    private let userAgent = "contact: buru.aoshin@gmail.com"

    /// 当月〜 monthsAhead ヶ月先までのイベントを取得
    func fetchEvents(monthsAhead: Int = 2) async throws -> [ZeppEvent] {
        let calendar = Calendar.current
        let now = Date()
        var allEvents: [ZeppEvent] = []

        for offset in 0..<monthsAhead {
            guard let targetDate = calendar.date(byAdding: .month, value: offset, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: targetDate)
            guard let year = comps.year, let month = comps.month else { continue }

            let days = try await fetchEventDays(year: year, month: month)
            for day in days {
                let events = try await fetchEventsForDay(year: year, month: month, day: day)
                allEvents.append(contentsOf: events)
            }
        }

        // 過去イベントを除外して日時順にソート
        return allEvents
            .filter { $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Private

    private func fetchEventDays(year: Int, month: Int) async throws -> [Int] {
        guard let url = URL(string: "\(baseURL)?_y=\(year)&_m=\(month)") else { return [] }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return []
        }

        let doc = try SwiftSoup.parse(html)
        let cells = try doc.select(".event-calendar-date")

        var days = Set<Int>()
        for cell in cells.array() {
            // イベントがある日は <a> リンクあり（disabled-date は <span>）
            let links = try cell.select("a")
            guard !links.isEmpty() else { continue }

            let href = try links.first()!.attr("href")
            // href 例: ?_y=2026&_m=3&_d=3
            if let components = URLComponents(string: href),
               let dayValue = components.queryItems?.first(where: { $0.name == "_d" })?.value,
               let day = Int(dayValue) {
                days.insert(day)
            }
        }
        // 平日（月〜金）のイベントのみ対象とし、週末はスクレイピングしない
        let jst = TimeZone(identifier: "Asia/Tokyo")!
        var jstCalendar = Calendar(identifier: .gregorian)
        jstCalendar.timeZone = jst
        return Array(days).sorted().filter { day in
            var comps = DateComponents(timeZone: jst, year: year, month: month, day: day)
            guard let date = jstCalendar.date(from: comps) else { return false }
            let weekday = jstCalendar.component(.weekday, from: date)
            return weekday != 1 && weekday != 7  // 1=日曜, 7=土曜
        }
    }

    private func fetchEventsForDay(year: Int, month: Int, day: Int) async throws -> [ZeppEvent] {
        guard let url = URL(string: "\(baseURL)?_y=\(year)&_m=\(month)&_d=\(day)") else { return [] }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return []
        }

        let doc = try SwiftSoup.parse(html)
        let eventElements = try doc.select(".sch-contentWrap .sch-content")

        var events: [ZeppEvent] = []
        for el in eventElements.array() {
            if let event = try parseEvent(el, year: year, month: month, day: day) {
                events.append(event)
            }
        }
        return events
    }

    private func parseEvent(_ el: Element, year: Int, month: Int, day: Int) throws -> ZeppEvent? {
        let performer = try el.select(".sch-content-text__performer").text().trimmingCharacters(in: .whitespaces)
        let title     = try el.select(".sch-content-text__ttl").text().trimmingCharacters(in: .whitespaces)
        let openStr   = try el.select(".sch-content-text-date__open").text().trimmingCharacters(in: .whitespaces)
        let startStr  = try el.select(".sch-content-text-date__start").text().trimmingCharacters(in: .whitespaces)

        guard !performer.isEmpty, !startStr.isEmpty else { return nil }

        guard let startTime = parseTime(startStr, year: year, month: month, day: day) else { return nil }
        let openTime = parseTime(openStr, year: year, month: month, day: day)

        // 深夜公演（例: 24:00 など）は翌日扱い済み（parseTime内で処理）
        let id = String(format: "%04d-%02d-%02d-%@", year, month, day, performer)

        return ZeppEvent(
            id: id,
            performer: performer,
            title: title,
            openTime: openTime,
            startTime: startTime
        )
    }

    /// "HH:MM" 形式の文字列を Date に変換（JST基準）
    private func parseTime(_ timeStr: String, year: Int, month: Int, day: Int) -> Date? {
        guard !timeStr.isEmpty else { return nil }
        let parts = timeStr.split(separator: ":").map { String($0) }
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        var jst = TimeZone(identifier: "Asia/Tokyo")!
        var comps = DateComponents(timeZone: jst, year: year, month: month, day: day, hour: hour, minute: minute)

        // 深夜公演（hour >= 24）は翌日として扱う
        if hour >= 24 {
            comps.hour = hour - 24
            comps.day = day + 1
        }

        return Calendar(identifier: .gregorian).date(from: comps)
    }
}
