import Foundation

/// 平日 17:00〜21:00 JST をアクティブウィンドウと定義する
enum TimeWindow {
    private static let jst = TimeZone(identifier: "Asia/Tokyo")!

    /// 指定日時がアクティブウィンドウ内か（デフォルト: 現在時刻）
    static func isActive(_ date: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = jst

        let weekday = cal.component(.weekday, from: date)
        guard weekday != 1 && weekday != 7 else { return false }  // 1=日, 7=土

        let hour = cal.component(.hour, from: date)
        return hour >= 17 && hour < 21  // 17:00 以上 21:00 未満
    }
}
