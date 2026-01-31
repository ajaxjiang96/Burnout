import Foundation
import UserNotifications
import os

public protocol NotificationServiceProtocol: Sendable {
    func requestPermission() async throws -> Bool
    func checkAndNotify(for usage: ClaudeWebUsage?, gemini: GeminiUsage?) async
}

public actor NotificationService: NotificationServiceProtocol {
    private let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "NotificationService")
    private let center = UNUserNotificationCenter.current()
    
    // Track state to prevent spamming
    private var lastClaudeState: UsageState = .normal
    private var lastGeminiState: UsageState = .normal
    
    private enum UsageState: Int, Comparable {
        case normal = 0
        case warning = 1 // > 80%
        case critical = 2 // > 95%
        case exhausted = 3 // 100%
        
        static func < (lhs: UsageState, rhs: UsageState) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    public init() {}

    public func requestPermission() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound]
        return try await center.requestAuthorization(options: options)
    }

    public func checkAndNotify(for usage: ClaudeWebUsage?, gemini: GeminiUsage?) async {
        await checkClaude(usage)
        await checkGemini(gemini)
    }

    private func checkClaude(_ usage: ClaudeWebUsage?) async {
        guard let usage = usage else { return }
        
        let percentage = usage.maxUtilization
        let newState = determineState(percentage)
        
        // Only notify if state has escalated
        if newState > lastClaudeState {
            if newState == .warning {
                scheduleNotification(
                    title: "Claude Quota Warning",
                    body: "You've used \(Int(percentage * 100))% of your quota.",
                    identifier: "claude-warning"
                )
            } else if newState == .critical {
                scheduleNotification(
                    title: "Claude Quota Critical",
                    body: "Approaching limit! \(Int(percentage * 100))% used.",
                    identifier: "claude-critical"
                )
            } else if newState == .exhausted {
                if let resetDate = usage.soonestReset {
                    scheduleResetNotification(at: resetDate, serviceName: "Claude")
                }
            }
        } else if newState < lastClaudeState {
            // Reset state if usage dropped (e.g. reset happened)
            // Cancel any pending reset notification if we are back in business
            if lastClaudeState == .exhausted {
                 center.removePendingNotificationRequests(withIdentifiers: ["claude-reset"])
            }
        }
        
        lastClaudeState = newState
    }
    
    private func checkGemini(_ usage: GeminiUsage?) async {
        guard let usage = usage else { return }
        
        let percentage = usage.maxUsagePercentage / 100.0
        let newState = determineState(percentage)
        
        if newState > lastGeminiState {
            if newState == .warning {
                scheduleNotification(
                    title: "Gemini Quota Warning",
                    body: "You've used \(Int(percentage * 100))% of your quota.",
                    identifier: "gemini-warning"
                )
            } else if newState == .critical {
                scheduleNotification(
                    title: "Gemini Quota Critical",
                    body: "Approaching limit! \(Int(percentage * 100))% used.",
                    identifier: "gemini-critical"
                )
            } else if newState == .exhausted {
                // Find reset time for the exhausted bucket
                if let bucket = usage.buckets.first(where: { $0.usagePercentage >= 100 }) {
                     let formatter = ISO8601DateFormatter()
                     formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                     if let date = formatter.date(from: bucket.resetTime) ?? ISO8601DateFormatter().date(from: bucket.resetTime) {
                         scheduleResetNotification(at: date, serviceName: "Gemini")
                     }
                }
            }
        } else if newState < lastGeminiState {
            if lastGeminiState == .exhausted {
                center.removePendingNotificationRequests(withIdentifiers: ["gemini-reset"])
            }
        }
        
        lastGeminiState = newState
    }

    private func determineState(_ percentage: Double) -> UsageState {
        if percentage >= 1.0 { return .exhausted }
        if percentage >= 0.95 { return .critical }
        if percentage >= 0.80 { return .warning }
        return .normal
    }

    private func scheduleNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil) // Immediate
        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func scheduleResetNotification(at date: Date, serviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(serviceName) Quota Reset"
        content.body = "You're back in business! Your quota has reset."
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "\(serviceName.lowercased())-reset", content: content, trigger: trigger)
        center.add(request)
        logger.info("Scheduled reset notification for \(serviceName) at \(date)")
    }
}
