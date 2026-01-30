import SwiftUI
import Combine
import os

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
    private nonisolated static let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "UsageViewModel")
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

    @Published public var geminiExecutablePath: String = UserDefaults.standard.string(forKey: "burnout_gemini_executable_path")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" {
        didSet {
            let cleanPath = geminiExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPath != geminiExecutablePath {
                geminiExecutablePath = cleanPath
            }
            UserDefaults.standard.set(cleanPath, forKey: "burnout_gemini_executable_path")
            refresh()
        }
    }

    @Published public var webUsage: ClaudeWebUsage? = nil
    @Published public var geminiUsage: GeminiUsage? = nil

    private let service: UsageServiceProtocol
    private let geminiService: GeminiUsageServiceProtocol

    public init() {
        self.service = ClaudeUsageService()
        self.geminiService = GeminiUsageService()
        
        // Migrate legacy setting if needed
        if let legacyPath = UserDefaults.standard.string(forKey: "burnout_gemini_log_path"), geminiExecutablePath.isEmpty {
            // Only migrate if it looks like an executable, not a log file
            if !legacyPath.hasSuffix(".log") && !legacyPath.hasSuffix(".json") {
                 geminiExecutablePath = legacyPath
            }
        }
        
        refresh()
        startPolling()
    }

    /// Preview-only initializer that sets mock state without triggering network or polling.
    init(
        webUsage: ClaudeWebUsage?,
        geminiUsage: GeminiUsage? = nil,
        error: String? = nil
    ) {
        self.service = ClaudeUsageService()
        self.geminiService = GeminiUsageService()
        self.webUsage = webUsage
        self.geminiUsage = geminiUsage
        self.error = error
    }

    public func refresh() {
        Task {
            self.error = nil
            
            await withTaskGroup(of: Void.self) { group in
                if hasClaudeCredentials {
                    group.addTask {
                        do {
                            let usage = try await self.service.fetchWebUsage(sessionKey: self.sessionKey, organizationId: self.organizationId)
                            await MainActor.run { self.webUsage = usage }
                        } catch {
                            Self.logger.error("Claude usage refresh failed: \(error)")
                            await MainActor.run { self.error = (self.error ?? "") + "Claude: " + error.localizedDescription + "\n" }
                        }
                    }
                }
                
                if hasGeminiConfig {
                    group.addTask {
                        do {
                            let gUsage = try await self.geminiService.fetchUsage(executablePath: self.geminiExecutablePath)
                            await MainActor.run { self.geminiUsage = gUsage }
                        } catch {
                            Self.logger.error("Gemini usage refresh failed: \(error)")
                            await MainActor.run { self.error = (self.error ?? "") + "Gemini: " + error.localizedDescription + "\n" }
                        }
                    }
                }
            }
            
            self.lastUpdated = Date()
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
        hasClaudeCredentials || hasGeminiConfig
    }

    public var hasClaudeCredentials: Bool {
        !sessionKey.isEmpty && !organizationId.isEmpty
    }
    
    public var hasGeminiConfig: Bool {
        !geminiExecutablePath.isEmpty
    }

    public var usagePercentage: Double {
        var percentage = 0.0
        
        if let usage = webUsage {
            switch displayedUsage {
            case .highest:
                percentage = usage.maxUtilization
            case .session:
                percentage = usage.fiveHour.utilization / 100.0
            case .weekly:
                percentage = usage.sevenDay.utilization / 100.0
            }
        }
        
        if let gemini = geminiUsage {
            let geminiMax = gemini.maxUsagePercentage / 100.0
            percentage = max(percentage, geminiMax)
        }
        
        return percentage
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