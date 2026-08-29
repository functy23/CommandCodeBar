import Foundation

enum Fmt {
    /// 额度数值，保留两位小数
    static func credits(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// 紧凑数字：456163537 → "456.2M"，63.67 → "63.7"
    static func compact(_ value: Double) -> String {
        let units: [(threshold: Double, suffix: String)] = [
            (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K"),
        ]
        for unit in units where value >= unit.threshold {
            return String(format: "%.1f%@", value / unit.threshold, unit.suffix)
        }
        return String(format: "%.0f", value)
    }

    static func percent(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        if clamped > 0 && clamped < 0.005 { return "<1%" }
        return String(format: "%.0f%%", clamped * 100)
    }

    static func countdown(until date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "即将刷新" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours >= 24 {
            return "\(hours / 24) 天 \(hours % 24) 小时后重置"
        }
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分后重置"
        }
        return "\(max(minutes, 1)) 分钟后重置"
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
