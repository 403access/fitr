import Foundation

enum FitrDate {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }()

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    private static let parseFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    static func date(_ key: String) -> Date {
        parseFormatter.date(from: key) ?? Date()
    }

    static func startOfWeek(_ date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    static func addDays(_ days: Int, to date: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func greeting(for date: Date = Date()) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night"
        }
    }

    static func dayNumber(_ date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    static func shortDate(_ key: String) -> String {
        let value = date(key)
        return value.formatted(.dateTime.month(.abbreviated).day())
    }

    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    static func relativeLabel(_ key: String, today: Date = Date()) -> String {
        let value = date(key)
        if calendar.isDateInToday(value) { return "Today" }
        if calendar.isDateInYesterday(value) { return "Yesterday" }
        if calendar.isDateInTomorrow(value) { return "Tomorrow" }
        return value.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func weekDates(containing date: Date) -> [Date] {
        let start = startOfWeek(date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func minutes(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded < 60 { return "\(rounded) min" }
        let hours = rounded / 60
        let minutes = rounded % 60
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) m"
    }

    static func delta(_ value: Double?) -> String {
        guard let value else { return "new" }
        if abs(value) < 0.05 { return "0%" }
        let signal = value > 0 ? "+" : ""
        return "\(signal)\(String(format: "%.1f", value))%"
    }

    static func weight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }

    static func number(_ value: Double) -> String {
        if value >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
