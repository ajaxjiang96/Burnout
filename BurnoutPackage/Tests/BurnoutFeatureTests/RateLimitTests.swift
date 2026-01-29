import Testing
import Foundation
@testable import BurnoutFeature

@Test func testClaudeWebUsageCalculations() {
    let resetTime = Date().addingTimeInterval(3600) // 1 hour later

    let usage = ClaudeWebUsage(
        fiveHour: UsageWindow(utilization: 25.0, resetsAt: resetTime),
        sevenDay: UsageWindow(utilization: 50.0, resetsAt: resetTime)
    )

    // Max utilization should be 50% (0.5 in 0-1 scale)
    #expect(abs(usage.maxUtilization - 0.5) < 0.001)

    // Soonest reset should be the same since both are equal
    #expect(usage.soonestReset == resetTime)
}

@Test func testClaudeWebUsageHighSessionUsage() {
    let sessionReset = Date().addingTimeInterval(1800) // 30 min
    let weeklyReset = Date().addingTimeInterval(86400) // 1 day

    let usage = ClaudeWebUsage(
        fiveHour: UsageWindow(utilization: 95.0, resetsAt: sessionReset),
        sevenDay: UsageWindow(utilization: 40.0, resetsAt: weeklyReset)
    )

    // Max should be 95%
    #expect(abs(usage.maxUtilization - 0.95) < 0.001)

    // Soonest reset should be sessionReset
    #expect(usage.soonestReset == sessionReset)
}

@Test func testClaudeWebUsageZeroUsage() {
    let usage = ClaudeWebUsage(
        fiveHour: UsageWindow(utilization: 0.0, resetsAt: nil),
        sevenDay: UsageWindow(utilization: 0.0, resetsAt: nil)
    )

    #expect(usage.maxUtilization == 0.0)
    #expect(usage.soonestReset == nil)
}

@Test func testUsageWindowDecoding() throws {
    let json = """
    {
        "utilization": 49.0,
        "resets_at": "2026-02-02T06:00:00.469344+00:00"
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
    }

    let window = try decoder.decode(UsageWindow.self, from: Data(json.utf8))

    #expect(window.utilization == 49.0)
    #expect(window.resetsAt != nil)
}

@Test func testClaudeWebUsageDecoding() throws {
    let json = """
    {
        "five_hour": { "utilization": 0.0, "resets_at": null },
        "seven_day": { "utilization": 49.0, "resets_at": "2026-02-02T06:00:00.469344+00:00" }
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
    }

    let usage = try decoder.decode(ClaudeWebUsage.self, from: Data(json.utf8))

    #expect(usage.fiveHour.utilization == 0.0)
    #expect(usage.fiveHour.resetsAt == nil)
    #expect(usage.sevenDay.utilization == 49.0)
    #expect(usage.sevenDay.resetsAt != nil)
    #expect(abs(usage.maxUtilization - 0.49) < 0.001)
}
