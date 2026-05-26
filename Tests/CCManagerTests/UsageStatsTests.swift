import XCTest
@testable import CCManager

final class UsageStatsTests: XCTestCase {
    func testParsesCurrentCcusageDailyJSONShape() throws {
        let json = """
        {
          "type": "daily",
          "data": [
            {
              "date": "2026-05-08",
              "models": ["claude-sonnet-4-20250514"],
              "inputTokens": 100,
              "outputTokens": 200,
              "cacheCreationTokens": 30,
              "cacheReadTokens": 40,
              "totalTokens": 370,
              "costUSD": 1.25
            }
          ],
          "summary": {
            "totalInputTokens": 100,
            "totalOutputTokens": 200,
            "totalCacheCreationTokens": 30,
            "totalCacheReadTokens": 40,
            "totalTokens": 370,
            "totalCostUSD": 1.25
          }
        }
        """

        let report = try UsageStatsParser.parse(Data(json.utf8))

        XCTAssertEqual(report.entries.count, 1)
        XCTAssertEqual(report.entries[0].date, "2026-05-08")
        XCTAssertEqual(report.entries[0].models, ["claude-sonnet-4-20250514"])
        XCTAssertEqual(report.summary.totalTokens, 370)
        XCTAssertEqual(report.summary.totalCostUSD, 1.25)
    }

    func testParsesLegacyCcusageDailyJSONShape() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2026-05-08",
              "modelsUsed": ["claude-opus-4-20250514"],
              "inputTokens": 10,
              "outputTokens": 20,
              "cacheCreationTokens": 3,
              "cacheReadTokens": 4,
              "totalTokens": 37,
              "totalCost": 0.42
            }
          ],
          "totals": {
            "inputTokens": 10,
            "outputTokens": 20,
            "cacheCreationTokens": 3,
            "cacheReadTokens": 4,
            "totalTokens": 37,
            "totalCost": 0.42
          }
        }
        """

        let report = try UsageStatsParser.parse(Data(json.utf8))

        XCTAssertEqual(report.entries.count, 1)
        XCTAssertEqual(report.entries[0].models, ["claude-opus-4-20250514"])
        XCTAssertEqual(report.summary.inputTokens, 10)
        XCTAssertEqual(report.summary.outputTokens, 20)
        XCTAssertEqual(report.summary.cacheCreationTokens, 3)
        XCTAssertEqual(report.summary.cacheReadTokens, 4)
        XCTAssertEqual(report.summary.totalCostUSD, 0.42)
    }

    func testParsesCodexCcusageDailyJSONShape() throws {
        let json = """
        {
          "daily": [
            {
              "date": "Mar 06, 2026",
              "inputTokens": 2023690,
              "cachedInputTokens": 1756544,
              "outputTokens": 36434,
              "reasoningOutputTokens": 22655,
              "totalTokens": 2060124,
              "costUSD": 1.2849767,
              "models": {
                "gpt-5.3-codex": {
                  "inputTokens": 2023690,
                  "cachedInputTokens": 1756544,
                  "outputTokens": 36434,
                  "reasoningOutputTokens": 22655,
                  "totalTokens": 2060124,
                  "isFallback": false
                }
              }
            }
          ],
          "totals": {
            "inputTokens": 2023690,
            "cachedInputTokens": 1756544,
            "outputTokens": 36434,
            "reasoningOutputTokens": 22655,
            "totalTokens": 2060124,
            "costUSD": 1.2849767
          }
        }
        """

        let report = try UsageStatsParser.parse(Data(json.utf8))

        XCTAssertEqual(report.entries.count, 1)
        XCTAssertEqual(report.entries[0].date, "2026-03-06")
        XCTAssertEqual(report.entries[0].inputTokens, 2_023_690)
        XCTAssertEqual(report.entries[0].cacheCreationTokens, 1_756_544)
        XCTAssertEqual(report.entries[0].models, ["Codex gpt-5.3-codex"])
        XCTAssertEqual(report.summary.totalTokens, 2_060_124)
        XCTAssertEqual(report.summary.totalCostUSD, 1.2849767)
    }

    func testAggregatesDailyEntriesByWeekAndMonth() throws {
        let entries = [
            UsageDailyEntry(date: "2026-05-04", inputTokens: 10, outputTokens: 10, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 20, costUSD: 0.1, models: []),
            UsageDailyEntry(date: "2026-05-05", inputTokens: 20, outputTokens: 20, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 40, costUSD: 0.2, models: []),
            UsageDailyEntry(date: "2026-06-01", inputTokens: 30, outputTokens: 30, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 60, costUSD: 0.3, models: [])
        ]

        let weekly = UsageStatsAggregator.aggregate(entries, by: .week)
        let monthly = UsageStatsAggregator.aggregate(entries, by: .month)

        XCTAssertEqual(weekly.map(\.label), ["2026-W19", "2026-W23"])
        XCTAssertEqual(weekly[0].totalTokens, 60)
        XCTAssertEqual(weekly[0].costUSD, 0.3, accuracy: 0.0001)
        XCTAssertEqual(monthly.map(\.label), ["2026-05", "2026-06"])
        XCTAssertEqual(monthly[0].totalTokens, 60)
        XCTAssertEqual(monthly[1].totalTokens, 60)
    }

    func testMergesEntriesByDateForCombinedClaudeAndCodexTotals() {
        let claude = UsageReport(entries: [
            UsageDailyEntry(date: "2026-05-08", inputTokens: 100, outputTokens: 200, cacheCreationTokens: 30, cacheReadTokens: 40, totalTokens: 370, costUSD: 1.25, models: ["Claude Code"]),
            UsageDailyEntry(date: "2026-05-09", inputTokens: 10, outputTokens: 20, cacheCreationTokens: 0, cacheReadTokens: 0, totalTokens: 30, costUSD: 0.1, models: ["Claude Code"])
        ], summary: UsageSummary(inputTokens: 110, outputTokens: 220, cacheCreationTokens: 30, cacheReadTokens: 40, totalTokens: 400, totalCostUSD: 1.35))

        let codex = UsageReport(entries: [
            UsageDailyEntry(date: "2026-05-08", inputTokens: 300, outputTokens: 400, cacheCreationTokens: 250, cacheReadTokens: 0, totalTokens: 700, costUSD: 0, models: ["Codex"])
        ], summary: UsageSummary(inputTokens: 300, outputTokens: 400, cacheCreationTokens: 250, cacheReadTokens: 0, totalTokens: 700, totalCostUSD: 0))

        let merged = UsageReport.merged([claude, codex])

        XCTAssertEqual(merged.entries.map(\.date), ["2026-05-08", "2026-05-09"])
        XCTAssertEqual(merged.entries[0].inputTokens, 400)
        XCTAssertEqual(merged.entries[0].outputTokens, 600)
        XCTAssertEqual(merged.entries[0].cacheCreationTokens, 280)
        XCTAssertEqual(merged.entries[0].totalTokens, 1_070)
        XCTAssertEqual(merged.entries[0].models, ["Claude Code", "Codex"])
        XCTAssertEqual(merged.summary.totalTokens, 1_100)
    }

    func testFormatsLargeTokenCountsWithCompactEnglishUnits() {
        XCTAssertEqual(UsageValueFormatter.tokenCount(999), "999")
        XCTAssertEqual(UsageValueFormatter.tokenCount(1_200), "1.2k")
        XCTAssertEqual(UsageValueFormatter.tokenCount(12_300), "12.3k")
        XCTAssertEqual(UsageValueFormatter.tokenCount(1_200_000), "1.2m")
        XCTAssertEqual(UsageValueFormatter.tokenCount(12_000_000), "12m")
        XCTAssertEqual(UsageValueFormatter.tokenCount(200_000_000), "2b")
        XCTAssertEqual(UsageValueFormatter.tokenCount(1_000_000_000), "10b")
        XCTAssertEqual(UsageValueFormatter.tokenCount(1_000_000_000_000), "1t")
        XCTAssertEqual(UsageValueFormatter.currencyUSD(12.3), "$12.30")
    }

    func testEnhancedCommandPathIncludesUserPackageManagerBins() {
        let path = UsageCommandResolver.enhancedPath(
            currentPath: "/usr/bin:/bin",
            homeDirectory: URL(fileURLWithPath: "/Users/sanyi")
        )
        let components = path.split(separator: ":").map(String.init)

        XCTAssertTrue(components.contains("/Users/sanyi/.bun/bin"))
        XCTAssertTrue(components.contains("/Users/sanyi/.npm-global/bin"))
        XCTAssertTrue(components.contains("/Users/sanyi/Library/pnpm"))
        XCTAssertTrue(components.contains("/opt/homebrew/bin"))
        XCTAssertEqual(components.filter { $0 == "/usr/bin" }.count, 1)
    }

    func testShellEnvironmentProvidesZshAndEnhancedPath() {
        let environment = UsageCommandResolver.shellEnvironment()
        let path = environment["PATH"] ?? ""

        XCTAssertEqual(environment["SHELL"], "/bin/zsh")
        XCTAssertTrue(path.contains("/opt/homebrew/bin"))
        XCTAssertTrue(path.contains("/.bun/bin"))
    }
}
