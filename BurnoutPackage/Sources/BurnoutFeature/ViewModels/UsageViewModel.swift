import SwiftUI
import Combine
import os
import ServiceManagement

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

    @Published public var isClaudeEnabled: Bool = UserDefaults.standard.object(forKey: "burnout_claude_enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isClaudeEnabled, forKey: "burnout_claude_enabled")
            if isClaudeEnabled { refresh() } else { webUsage = nil }
        }
    }

    @Published public var isGeminiEnabled: Bool = UserDefaults.standard.object(forKey: "burnout_gemini_enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isGeminiEnabled, forKey: "burnout_gemini_enabled")
            if isGeminiEnabled { refresh() } else { geminiUsage = nil }
        }
    }

    @Published public var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "burnout_launch_at_login") {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "burnout_launch_at_login")
            #if os(macOS)
            // Fallback to deprecated API as SMAppService.main is unavailable in this SDK version
            SMLoginItemSetEnabled("com.ajaxjiang.Burnout" as CFString, launchAtLogin)
            #endif
        }
    }

    @Published public var webUsage: ClaudeWebUsage? = nil
    @Published public var geminiUsage: GeminiUsage? = nil

    private let service: UsageServiceProtocol
    private let geminiService: GeminiUsageServiceProtocol

    public init() {
        self.service = ClaudeUsageService()
        self.geminiService = GeminiUsageService()
        
        refresh()
        startPolling()
    }

    /// Preview-only initializer that sets mock state without triggering network or polling.
    public init(
        webUsage: ClaudeWebUsage?,
        geminiUsage: GeminiUsage? = nil,
        isClaudeEnabled: Bool = true,
        isGeminiEnabled: Bool = true,
        error: String? = nil
    ) {
        self.service = ClaudeUsageService()
        self.geminiService = GeminiUsageService()
        self.webUsage = webUsage
        self.geminiUsage = geminiUsage
        self.isClaudeEnabled = isClaudeEnabled
        self.isGeminiEnabled = isGeminiEnabled
        self.error = error
    }

    public func refresh() {
        Task {
            self.error = nil
            
            await withTaskGroup(of: Void.self) { group in
                if isClaudeEnabled && hasClaudeCredentials {
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
                
                if isGeminiEnabled && hasGeminiCredentials {
                    group.addTask {
                        do {
                            let gUsage = try await self.geminiService.fetchUsage()
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
        (isClaudeEnabled && hasClaudeCredentials) || (isGeminiEnabled && hasGeminiCredentials)
    }

    public var hasClaudeCredentials: Bool {
        !sessionKey.isEmpty && !organizationId.isEmpty
    }
    
    public var hasGeminiCredentials: Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let credsPath = homeDir.appendingPathComponent(".gemini/oauth_creds.json")
        return FileManager.default.fileExists(atPath: credsPath.path)
    }

    public var usagePercentage: Double {
        max(claudePercentage, geminiPercentage)
    }

    public var claudePercentage: Double {
        guard let usage = webUsage else { return 0.0 }
        switch displayedUsage {
        case .highest:
            return usage.maxUtilization
        case .session:
            return usage.fiveHour.utilization / 100.0
        case .weekly:
            return usage.sevenDay.utilization / 100.0
        }
    }

    public var claudePercentageText: String {
        if claudePercentage >= 0.9, !claudeResetText.isEmpty {
            return claudeResetText
        } else {
            return "\(Int(claudePercentage * 100))%"
        }
    }

    public var geminiPercentage: Double {
        guard let gemini = geminiUsage else { return 0.0 }
        return gemini.maxUsagePercentage / 100.0
    }

    public var geminiPercentageText: String {
        if geminiPercentage >= 0.9, !geminiResetText.isEmpty {
            return geminiResetText
        } else {
            return "\(Int(geminiPercentage * 100))%"
        }
    }

    public var usageColor: Color {
        color(for: usagePercentage)
    }

    public func color(for percentage: Double) -> Color {
        switch percentage {
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
        guard let date = soonestResetDate else { return "" }
        return formatResetTime(date)
    }

    public var claudeResetText: String {
        guard let date = webUsage?.soonestReset else { return "" }
        return formatResetTime(date)
    }

    public var geminiResetText: String {
        guard let date = geminiSoonestResetDate else { return "" }
        return formatResetTime(date)
    }

    public var soonestResetDate: Date? {
        let claudeReset = webUsage?.soonestReset
        let geminiReset = geminiSoonestResetDate
        
        switch (claudeReset, geminiReset) {
        case (.some(let c), .some(let g)):
            return min(c, g)
        case (.some(let c), .none):
            return c
        case (.none, .some(let g)):
            return g
        case (.none, .none):
            return nil
        }
    }

    public var geminiSoonestResetDate: Date? {
        guard let gemini = geminiUsage else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let dates = gemini.buckets.compactMap { bucket -> Date? in
            formatter.date(from: bucket.resetTime) ?? ISO8601DateFormatter().date(from: bucket.resetTime)
        }
        return dates.min()
    }

    public func formatResetTime(_ date: Date) -> String {
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 { return "Reset..." }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        return formatter.string(from: diff) ?? ""
    }
}
