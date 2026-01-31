import SwiftUI
import Combine
import os
import ServiceManagement
import Observation

@MainActor
@Observable
public class UsageViewModel {
    private nonisolated static let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "UsageViewModel")
    public var lastUpdated: Date = Date()
    public var error: String? = nil

    public var sessionKey: String = UserDefaults.standard.string(forKey: "burnout_session_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" {
        didSet {
            let cleanKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanKey != sessionKey {
                sessionKey = cleanKey
            }
            UserDefaults.standard.set(cleanKey, forKey: "burnout_session_key")
            refresh()
        }
    }

    public var organizationId: String = UserDefaults.standard.string(forKey: "burnout_org_id")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" {
        didSet {
            let cleanId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanId != organizationId {
                organizationId = cleanId
            }
            UserDefaults.standard.set(cleanId, forKey: "burnout_org_id")
            refresh()
        }
    }

    public var isClaudeEnabled: Bool = UserDefaults.standard.object(forKey: "burnout_claude_enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isClaudeEnabled, forKey: "burnout_claude_enabled")
            if isClaudeEnabled { refresh() } else { webUsage = nil }
        }
    }

        public var isGeminiEnabled: Bool = UserDefaults.standard.object(forKey: "burnout_gemini_enabled") as? Bool ?? true {

            didSet {

                UserDefaults.standard.set(isGeminiEnabled, forKey: "burnout_gemini_enabled")

                if isGeminiEnabled { refresh() } else { geminiUsage = nil }

            }

        }

    

        public var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "burnout_notifications_enabled") {

            didSet {

                UserDefaults.standard.set(notificationsEnabled, forKey: "burnout_notifications_enabled")

                if notificationsEnabled {

                    Task {

                        _ = try? await notificationService.requestPermission()

                    }

                }

            }

        }

    

        public var launchAtLogin: Bool = {

            #if os(macOS)

            return SMAppService.mainApp.status == .enabled

            #else

            return false

            #endif

        }() {

            didSet {

                #if os(macOS)

                guard oldValue != launchAtLogin else { return }

                do {

                    if launchAtLogin {

                        if SMAppService.mainApp.status != .enabled {

                            try SMAppService.mainApp.register()

                        }

                    } else {

                        if SMAppService.mainApp.status == .enabled {

                            try SMAppService.mainApp.unregister()

                        }

                    }

                } catch {

                    Self.logger.error("Failed to toggle launch at login: \(error)")

                }

                #endif

            }

        }

    

        public var webUsage: ClaudeWebUsage? = nil

        public var geminiUsage: GeminiUsage? = nil

        public var latestRelease: GitHubRelease? = nil

    

        private var lastChangedClaude: Date = .distantPast

        private var lastChangedGemini: Date = .distantPast

    

        public struct MenuBarDisplayItem {

            public let icon: String

            public let text: String

            public let color: Color

        }

    

        private let service: UsageServiceProtocol

        private let geminiService: GeminiUsageServiceProtocol

        private let notificationService: NotificationServiceProtocol

        private let updateService: UpdateServiceProtocol

    

        public init(

            updateService: UpdateServiceProtocol = GitHubUpdateService(),

            notificationService: NotificationServiceProtocol = NotificationService()

        ) {

            self.service = ClaudeUsageService()

            self.geminiService = GeminiUsageService()

            self.updateService = updateService

            self.notificationService = notificationService

            

            if notificationsEnabled {

                Task { _ = try? await notificationService.requestPermission() }

            }

            

            refresh()

            startPolling()

            checkForUpdates()

        }

    

            /// Preview-only initializer that sets mock state without triggering network or polling.

    

            public init(

    

                webUsage: ClaudeWebUsage?,

    

                geminiUsage: GeminiUsage? = nil,

    

                isClaudeEnabled: Bool = true,

    

                isGeminiEnabled: Bool = true,

    

                error: String? = nil,

    

                latestRelease: GitHubRelease? = nil,

    

                updateService: UpdateServiceProtocol = GitHubUpdateService(),

    

                notificationService: NotificationServiceProtocol = NotificationService()

    

            ) {

    

                self.service = ClaudeUsageService()

    

                self.geminiService = GeminiUsageService()

    

                self.updateService = updateService

    

                self.notificationService = notificationService

    

                self.webUsage = webUsage

    

                self.geminiUsage = geminiUsage

    

                self.isClaudeEnabled = isClaudeEnabled

    

                self.isGeminiEnabled = isGeminiEnabled

    

                self.error = error

    

                self.latestRelease = latestRelease

    

                

    

                // Initialize timestamps for preview

    

                if webUsage != nil { lastChangedClaude = Date() }

    

                if geminiUsage != nil { lastChangedGemini = Date() }

    

            }

    

        public func refresh() {

            Task {

                self.error = nil

                

                await withTaskGroup(of: Void.self) { group in

                    if isClaudeEnabled && hasClaudeCredentials {

                        group.addTask {

                            do {

                                let newUsage = try await self.service.fetchWebUsage(sessionKey: self.sessionKey, organizationId: self.organizationId)

                                await MainActor.run {

                                    if self.webUsage != newUsage {

                                        self.webUsage = newUsage

                                        self.lastChangedClaude = Date()

                                    }

                                }

                            } catch {

                                Self.logger.error("Claude usage refresh failed: \(error)")

                                await MainActor.run { self.error = (self.error ?? "") + "Claude: " + error.localizedDescription + "\n" }

                            }

                        }

                    }

                    

                    if isGeminiEnabled && hasGeminiCredentials {

                        group.addTask {

                            do {

                                let newUsage = try await self.geminiService.fetchUsage()

                                await MainActor.run {

                                    if self.geminiUsage?.buckets != newUsage.buckets {

                                        self.geminiUsage = newUsage

                                        self.lastChangedGemini = Date()

                                    }

                                }

                            } catch {

                                Self.logger.error("Gemini usage refresh failed: \(error)")

                                await MainActor.run { self.error = (self.error ?? "") + "Gemini: " + error.localizedDescription + "\n" }

                            }

                        }

                    }

                }

                

                if notificationsEnabled {

                    await notificationService.checkAndNotify(for: webUsage, gemini: geminiUsage)

                }

                

                self.lastUpdated = Date()

            }

        }

    public func checkForUpdates() {
        Task {
            do {
                if let release = try await updateService.checkForUpdates() {
                    await MainActor.run {
                        self.latestRelease = release
                    }
                }
            } catch {
                Self.logger.error("Failed to check for updates: \(error)")
            }
        }
    }

    public var activeDisplayItem: MenuBarDisplayItem? {
        // Determine which service to show based on last update and activity
        // If one is disabled/missing, prefer the other.
        
        let showClaude = isClaudeEnabled && hasClaudeCredentials && webUsage != nil
        let showGemini = isGeminiEnabled && hasGeminiCredentials && geminiUsage != nil
        
        if showClaude && showGemini {
            // Prioritize active usage
            // Claude is active if session usage > 0
            // Gemini is active if usage > 0
            let claudeActive = (webUsage?.fiveHour.utilization ?? 0) > 0
            let geminiActive = (geminiUsage?.maxUsagePercentage ?? 0) > 0
            
            if geminiActive && !claudeActive {
                return geminiDisplayItem
            }
            if claudeActive && !geminiActive {
                return claudeDisplayItem
            }
            
            // Fallback to timestamp if both active or both inactive
            if lastChangedClaude >= lastChangedGemini {
                return claudeDisplayItem
            } else {
                return geminiDisplayItem
            }
        } else if showClaude {
            return claudeDisplayItem
        } else if showGemini {
            return geminiDisplayItem
        }
        
        return nil
    }
    
    private var claudeDisplayItem: MenuBarDisplayItem? {
        guard let usage = webUsage else { return nil }
        
        // Logic: Session usage unless Weekly > 95%
        let weeklyUtil = usage.sevenDay.utilization
        
        let targetWindow: UsageWindow
        if weeklyUtil > 95.0 {
            targetWindow = usage.sevenDay
        } else {
            targetWindow = usage.fiveHour
        }
        
        let utilization = targetWindow.utilization
        let percentage = utilization / 100.0
        
        let text: String
        let color: Color
        
        if utilization >= 100.0, let reset = targetWindow.resetsAt {
            text = formatResetTime(reset)
            color = .red
        } else {
            text = "\(Int(utilization))%"
            color = self.color(for: percentage)
        }
        
        return MenuBarDisplayItem(icon: "asterisk", text: text, color: color)
    }
    
    private var geminiDisplayItem: MenuBarDisplayItem? {
        guard let usage = geminiUsage else { return nil }
        
        // Logic: Always display Pro model
        // Look for "pro" in modelId (e.g. "gemini-1.5-pro")
        let proBucket = usage.buckets.first { $0.modelId.lowercased().contains("pro") }
        
        guard let bucket = proBucket else {
            // Fallback if no Pro model found? Use max?
            // For now, let's fallback to max usage if pro isn't found, or just show 0%
            return MenuBarDisplayItem(icon: "sparkle", text: "N/A", color: .secondary)
        }
        
        let percentage = bucket.usagePercentage
        let text: String
        let color: Color
        
        if percentage >= 100.0 {
            // Parse reset time
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: bucket.resetTime) ?? ISO8601DateFormatter().date(from: bucket.resetTime) {
                text = formatResetTime(date)
            } else {
                text = "Wait..."
            }
            color = .red
        } else {
            text = "\(Int(percentage))%"
            color = self.color(for: percentage / 100.0)
        }
        
        return MenuBarDisplayItem(icon: "sparkle", text: text, color: color)
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
    
    // Internal for testing
    var _mockGeminiCredentialsPresent: Bool? = nil

    public var hasGeminiCredentials: Bool {
        if let mock = _mockGeminiCredentialsPresent { return mock }
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let credsPath = homeDir.appendingPathComponent(".gemini/oauth_creds.json")
        return FileManager.default.fileExists(atPath: credsPath.path)
    }

    public var usagePercentage: Double {
        max(claudePercentage, geminiPercentage)
    }

    public var claudePercentage: Double {
        guard let usage = webUsage else { return 0.0 }
        return usage.maxUtilization
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

    public var simplifiedGeminiBuckets: [GeminiModelUsage] {
        guard let usage = geminiUsage else { return [] }
        
        var groups: [String: [GeminiModelUsage]] = [:]
        
        for bucket in usage.buckets {
            let id = bucket.modelId.lowercased()
            let familyName: String
            
            if id.contains("flash-lite") {
                familyName = "Gemini Flash-Lite"
            } else if id.contains("flash") {
                familyName = "Gemini Flash"
            } else if id.contains("pro") {
                familyName = "Gemini Pro"
            } else {
                familyName = bucket.modelId
                    .replacingOccurrences(of: "gemini-", with: "")
                    .capitalized
            }
            
            groups[familyName, default: []].append(bucket)
        }
        
        // For each group, pick the bucket with highest usage percentage
        let aggregated = groups.compactMap { (familyName, buckets) -> GeminiModelUsage? in
            guard let worstBucket = buckets.max(by: { $0.usagePercentage < $1.usagePercentage }) else { return nil }
            
            return GeminiModelUsage(
                modelId: familyName,
                tokenType: worstBucket.tokenType,
                remainingAmount: worstBucket.remainingAmount,
                remainingFraction: worstBucket.remainingFraction,
                resetTime: worstBucket.resetTime
            )
        }
        
        // Sort by predefined order: Pro, Flash, Flash-Lite
        let order = ["Gemini Pro": 0, "Gemini Flash": 1, "Gemini Flash-Lite": 2]
        return aggregated.sorted { (a, b) in
            let orderA = order[a.modelId] ?? 99
            let orderB = order[b.modelId] ?? 99
            if orderA != orderB {
                return orderA < orderB
            }
            return a.modelId < b.modelId
        }
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