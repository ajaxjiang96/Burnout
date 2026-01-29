import Foundation

public struct UsageWindow: Codable, Sendable, Equatable {
    public let utilization: Double
    public let resetsAt: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct ClaudeWebUsage: Codable, Sendable, Equatable {
    public let fiveHour: UsageWindow
    public let sevenDay: UsageWindow

    public init(fiveHour: UsageWindow, sevenDay: UsageWindow) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    /// Returns the maximum utilization between session and weekly windows (0-1 scale)
    public var maxUtilization: Double {
        max(fiveHour.utilization, sevenDay.utilization) / 100.0
    }

    /// Returns the soonest reset date among windows that have usage
    public var soonestReset: Date? {
        let dates = [fiveHour.resetsAt, sevenDay.resetsAt].compactMap { $0 }
        return dates.min()
    }
}
