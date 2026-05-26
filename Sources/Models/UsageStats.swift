import Foundation

struct UsageDailyEntry: Identifiable, Equatable {
    var id: String { date }
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let costUSD: Double
    let models: [String]
}

struct UsageSummary: Equatable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let totalCostUSD: Double
}

struct UsageReport: Equatable {
    let entries: [UsageDailyEntry]
    let summary: UsageSummary

    init(entries: [UsageDailyEntry], summary: UsageSummary) {
        self.entries = entries
        self.summary = summary
    }

    static func merged(_ reports: [UsageReport]) -> UsageReport {
        let groupedEntries = Dictionary(grouping: reports.flatMap(\.entries), by: \.date)
        let entries = groupedEntries.keys.sorted().map { date in
            let values = groupedEntries[date] ?? []
            let models = values
                .flatMap(\.models)
                .reduce(into: [String]()) { result, model in
                    if !result.contains(model) {
                        result.append(model)
                    }
                }

            return UsageDailyEntry(
                date: date,
                inputTokens: values.reduce(0) { $0 + $1.inputTokens },
                outputTokens: values.reduce(0) { $0 + $1.outputTokens },
                cacheCreationTokens: values.reduce(0) { $0 + $1.cacheCreationTokens },
                cacheReadTokens: values.reduce(0) { $0 + $1.cacheReadTokens },
                totalTokens: values.reduce(0) { $0 + $1.totalTokens },
                costUSD: values.reduce(0) { $0 + $1.costUSD },
                models: models
            )
        }

        return UsageReport(entries: entries, summary: UsageStatsAggregator.summary(for: entries))
    }
}

struct UsageBucket: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let costUSD: Double
}

enum UsageAggregation: String, CaseIterable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
}

enum UsageStatsParser {
    enum ParseError: Error {
        case unsupportedShape
    }

    static func parse(_ data: Data) throws -> UsageReport {
        let decoder = JSONDecoder()

        if let current = try? decoder.decode(CurrentCcusageDailyResponse.self, from: data), !current.data.isEmpty || current.summary != nil {
            let entries = current.data.map { $0.entry }
            return UsageReport(
                entries: entries,
                summary: current.summary?.summary ?? UsageStatsAggregator.summary(for: entries)
            )
        }

        if let legacy = try? decoder.decode(LegacyCcusageDailyResponse.self, from: data), !legacy.daily.isEmpty || legacy.totals != nil {
            let entries = legacy.daily.map { $0.entry }
            return UsageReport(
                entries: entries,
                summary: legacy.totals?.summary ?? UsageStatsAggregator.summary(for: entries)
            )
        }

        if let codex = try? decoder.decode(CodexCcusageDailyResponse.self, from: data), !codex.daily.isEmpty || codex.totals != nil {
            let entries = codex.daily.map { $0.entry }
            return UsageReport(
                entries: entries,
                summary: codex.totals?.summary ?? UsageStatsAggregator.summary(for: entries)
            )
        }

        throw ParseError.unsupportedShape
    }
}

enum UsageValueFormatter {
    static func tokenCount(_ value: Int) -> String {
        let units: [(threshold: Double, suffix: String)] = [
            (1_000_000_000_000, "t"),
            (100_000_000, "b"),
            (1_000_000, "m"),
            (1_000, "k")
        ]

        guard let unit = units.first(where: { Double(value) >= $0.threshold }) else {
            return decimal(value)
        }

        return "\(compactDecimal(Double(value) / unit.threshold))\(unit.suffix)"
    }

    static func currencyUSD(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private static func compactDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private static func decimal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

enum UsageStatsAggregator {
    static func aggregate(_ entries: [UsageDailyEntry], by aggregation: UsageAggregation) -> [UsageBucket] {
        switch aggregation {
        case .day:
            return entries
                .sorted { $0.date < $1.date }
                .map {
                    UsageBucket(
                        label: $0.date,
                        inputTokens: $0.inputTokens,
                        outputTokens: $0.outputTokens,
                        cacheCreationTokens: $0.cacheCreationTokens,
                        cacheReadTokens: $0.cacheReadTokens,
                        totalTokens: $0.totalTokens,
                        costUSD: $0.costUSD
                    )
                }
        case .week, .month:
            return groupedBuckets(entries, by: aggregation)
        }
    }

    static func summary(for entries: [UsageDailyEntry]) -> UsageSummary {
        UsageSummary(
            inputTokens: entries.reduce(0) { $0 + $1.inputTokens },
            outputTokens: entries.reduce(0) { $0 + $1.outputTokens },
            cacheCreationTokens: entries.reduce(0) { $0 + $1.cacheCreationTokens },
            cacheReadTokens: entries.reduce(0) { $0 + $1.cacheReadTokens },
            totalTokens: entries.reduce(0) { $0 + $1.totalTokens },
            totalCostUSD: entries.reduce(0) { $0 + $1.costUSD }
        )
    }

    private static func groupedBuckets(_ entries: [UsageDailyEntry], by aggregation: UsageAggregation) -> [UsageBucket] {
        let groups = Dictionary(grouping: entries) { entry -> String in
            switch aggregation {
            case .week:
                return weekLabel(for: entry.date)
            case .month:
                return String(entry.date.prefix(7))
            case .day:
                return entry.date
            }
        }

        return groups.keys.sorted().map { label in
            let values = groups[label] ?? []
            return UsageBucket(
                label: label,
                inputTokens: values.reduce(0) { $0 + $1.inputTokens },
                outputTokens: values.reduce(0) { $0 + $1.outputTokens },
                cacheCreationTokens: values.reduce(0) { $0 + $1.cacheCreationTokens },
                cacheReadTokens: values.reduce(0) { $0 + $1.cacheReadTokens },
                totalTokens: values.reduce(0) { $0 + $1.totalTokens },
                costUSD: values.reduce(0) { $0 + $1.costUSD }
            )
        }
    }

    private static func weekLabel(for dateString: String) -> String {
        guard let date = UsageDateFormatter.day.date(from: dateString) else {
            return dateString
        }
        let components = UsageDateFormatter.isoCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }
}

private enum UsageDateFormatter {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = isoCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let isoCalendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static func normalizedDayString(from value: String) -> String {
        if day.date(from: value) != nil {
            return value
        }

        let parser = DateFormatter()
        parser.calendar = isoCalendar
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "MMM dd, yyyy"

        guard let date = parser.date(from: value) else {
            return value
        }

        return day.string(from: date)
    }
}

private struct CurrentCcusageDailyResponse: Decodable {
    let data: [CurrentCcusageDailyEntry]
    let summary: CurrentCcusageSummary?
}

private struct CurrentCcusageDailyEntry: Decodable {
    let date: String
    let models: [String]?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let costUSD: Double?

    var entry: UsageDailyEntry {
        UsageDailyEntry(
            date: date,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            totalTokens: totalTokens,
            costUSD: costUSD ?? 0,
            models: models ?? []
        )
    }
}

private struct CurrentCcusageSummary: Decodable {
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCacheCreationTokens: Int
    let totalCacheReadTokens: Int
    let totalTokens: Int
    let totalCostUSD: Double?

    var summary: UsageSummary {
        UsageSummary(
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            cacheCreationTokens: totalCacheCreationTokens,
            cacheReadTokens: totalCacheReadTokens,
            totalTokens: totalTokens,
            totalCostUSD: totalCostUSD ?? 0
        )
    }
}

private struct LegacyCcusageDailyResponse: Decodable {
    let daily: [LegacyCcusageDailyEntry]
    let totals: LegacyCcusageTotals?
}

private struct LegacyCcusageDailyEntry: Decodable {
    let date: String
    let modelsUsed: [String]?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let totalCost: Double?

    var entry: UsageDailyEntry {
        UsageDailyEntry(
            date: date,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            totalTokens: totalTokens,
            costUSD: totalCost ?? 0,
            models: modelsUsed ?? []
        )
    }
}

private struct LegacyCcusageTotals: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let totalCost: Double?

    var summary: UsageSummary {
        UsageSummary(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            totalTokens: totalTokens,
            totalCostUSD: totalCost ?? 0
        )
    }
}

private struct CodexCcusageDailyResponse: Decodable {
    let daily: [CodexCcusageDailyEntry]
    let totals: CodexCcusageTotals?
}

private struct CodexCcusageDailyEntry: Decodable {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cachedInputTokens: Int
    let totalTokens: Int
    let costUSD: Double?
    let models: [String: CodexCcusageModelUsage]?

    var entry: UsageDailyEntry {
        UsageDailyEntry(
            date: UsageDateFormatter.normalizedDayString(from: date),
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cachedInputTokens,
            cacheReadTokens: 0,
            totalTokens: totalTokens,
            costUSD: costUSD ?? 0,
            models: modelNames
        )
    }

    private var modelNames: [String] {
        let names = (models ?? [:]).keys.sorted()
        return names.isEmpty ? ["Codex"] : names.map { "Codex \($0)" }
    }
}

private struct CodexCcusageModelUsage: Decodable {
    let inputTokens: Int?
    let cachedInputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
    let isFallback: Bool?
}

private struct CodexCcusageTotals: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cachedInputTokens: Int
    let totalTokens: Int
    let costUSD: Double?

    var summary: UsageSummary {
        UsageSummary(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cachedInputTokens,
            cacheReadTokens: 0,
            totalTokens: totalTokens,
            totalCostUSD: costUSD ?? 0
        )
    }
}
