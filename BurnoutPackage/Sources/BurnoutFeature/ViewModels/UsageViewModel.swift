import SwiftUI
import Combine

public enum MenuBarIcon: String, CaseIterable, Identifiable {
    case gauge = "Gauge"
    case flame = "Flame"

    public var id: String { rawValue }

    public func iconName(for percentage: Double) -> String {
        switch self {
        case .gauge:
            switch percentage {
            case ..<0.5:
                return "gauge.with.dots.needle.bottom.0percent"
            case 0.5..<0.9:
                return "gauge.with.dots.needle.bottom.50percent"
            default:
                return "gauge.with.dots.needle.bottom.100percent"
            }
        case .flame:
            switch percentage {
            case ..<0.5:
                return "flame"
            case 0.5..<0.9:
                return "flame.fill"
            default:
                return "exclamationmark.triangle.fill"
            }
        }
    }
}

public enum DisplayedUsage: String, CaseIterable, Identifiable {
    case highest = "Highest"
    case session = "Session (5h)"
    case weekly = "Weekly (7d)"

    public var id: String { rawValue }
}

@MainActor
public class UsageViewModel: ObservableObject {
    @Published public var lastUpdated: Date = Date()
    @Published public var error: String? = nil

    @Published public var sessionKey: String = UserDefaults.standard.string(forKey: "burnout_session_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" {
        didSet {
            let cleanKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanKey != sessionKey {
                sessionKey = cleanKey
            }
            UserDefaults.standard.set(cleanKey, forKey: "burnout_session_key")
            refresh()
        }
    }

    @Published public var organizationId: String = UserDefaults.standard.string(forKey: "burnout_org_id")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" {
        didSet {
            let cleanId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanId != organizationId {
                organizationId = cleanId
            }
            UserDefaults.standard.set(cleanId, forKey: "burnout_org_id")
            refresh()
        }
    }

    @Published public var displayedUsage: DisplayedUsage = DisplayedUsage(rawValue: UserDefaults.standard.string(forKey: "burnout_displayed_usage") ?? "") ?? .session {
        didSet {
            UserDefaults.standard.set(displayedUsage.rawValue, forKey: "burnout_displayed_usage")
        }
    }

    @Published public var menuBarIcon: MenuBarIcon = MenuBarIcon(rawValue: UserDefaults.standard.string(forKey: "burnout_menu_bar_icon") ?? "") ?? .gauge {
        didSet {
            UserDefaults.standard.set(menuBarIcon.rawValue, forKey: "burnout_menu_bar_icon")
        }
    }

    @Published public var webUsage: ClaudeWebUsage? = nil

    private let service: UsageServiceProtocol

    public init() {
        self.service = ClaudeUsageService()
        refresh()
        startPolling()
    }

    /// Preview-only initializer that sets mock state without triggering network or polling.
    init(
        webUsage: ClaudeWebUsage?,
        error: String? = nil
    ) {
        self.service = ClaudeUsageService()
        self.webUsage = webUsage
        self.error = error
    }

    public func refresh() {
        Task {
            do {
                if hasCredentials {
                    let usage = try await service.fetchWebUsage(sessionKey: sessionKey, organizationId: organizationId)
                    self.webUsage = usage
                }

                self.lastUpdated = Date()
                self.error = nil
            } catch {
                print("Usage refresh error: \(error)")
                self.error = error.localizedDescription
            }
        }
    }

    private func startPolling() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                refresh()
            }
        }
    }

    public var hasCredentials: Bool {
        !sessionKey.isEmpty && !organizationId.isEmpty
    }

    public var usagePercentage: Double {
        guard let usage = webUsage else { return 0 }
        switch displayedUsage {
        case .highest:
            return usage.maxUtilization
        case .session:
            return usage.fiveHour.utilization / 100.0
        case .weekly:
            return usage.sevenDay.utilization / 100.0
        }
    }

    public var menuBarIconName: String {
        menuBarIcon.iconName(for: usagePercentage)
    }

    public var usageColor: Color {
        switch usagePercentage {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .yellow
        case 0.8..<1.0: return .orange
        default: return .red
        }
    }

    public var sessionResetText: String {
        guard let usage = webUsage, let resetDate = usage.fiveHour.resetsAt else { return "" }
        return formatResetTime(resetDate)
    }

    public var weeklyResetText: String {
        guard let usage = webUsage, let resetDate = usage.sevenDay.resetsAt else { return "" }
        return formatResetTime(resetDate)
    }

    public var soonestResetText: String {
        guard let usage = webUsage, let resetDate = usage.soonestReset else { return "" }
        return formatResetTime(resetDate)
    }

    private func formatResetTime(_ date: Date) -> String {
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 { return "Resetting..." }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: diff) ?? ""
    }
}
