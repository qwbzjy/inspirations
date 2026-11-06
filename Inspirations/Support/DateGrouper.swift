import Foundation

enum DateGrouper {
    private static let zhLocale = Locale(identifier: "zh_CN")

    private static let sectionDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = zhLocale
        f.dateFormat = "M月d日 EEE"
        return f
    }()

    private static let sectionDayWithYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = zhLocale
        f.dateFormat = "yyyy年M月d日 EEE"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = zhLocale
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let detailFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = zhLocale
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    /// 分组标题：今天 / 昨天 / M月d日 周X（跨年含年份）
    static func sectionLabel(for day: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "昨天" }
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: now)
        return sameYear
            ? sectionDayFormatter.string(from: day)
            : sectionDayWithYearFormatter.string(from: day)
    }

    /// 行内时间 HH:mm
    static func timeLabel(for date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// 详情页完整时间 M月d日 HH:mm
    static func detailLabel(for date: Date) -> String {
        detailFormatter.string(from: date)
    }

    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
