import Testing
import Foundation
@testable import BurnoutFeature

@Suite("Usage Logic Tests")
struct UsageLogicTests {

    @MainActor
    @Test("Prioritize Gemini when Claude Session is 0 and Gemini is active")
    func prioritizeGeminiOverInactiveClaude() {
        // Setup Claude: Session 0%, Weekly 99% (The user's state)
        let claudeUsage = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 0.0, resetsAt: Date()),
            sevenDay: UsageWindow(utilization: 99.0, resetsAt: Date())
        )
        
        // Setup Gemini: Usage 50%
        let geminiUsage = GeminiUsage(
            buckets: [
                GeminiModelUsage(
                    modelId: "gemini-1.5-pro",
                    tokenType: "REQUESTS",
                    remainingAmount: "50",
                    remainingFraction: 0.5,
                    resetTime: ISO8601DateFormatter().string(from: Date())
                )
            ],
            lastUpdated: Date()
        )
        
        let vm = UsageViewModel(
            webUsage: claudeUsage,
            geminiUsage: geminiUsage,
            isClaudeEnabled: true,
            isGeminiEnabled: true
        )
        vm.sessionKey = "test"
        vm.organizationId = "test"
        vm._mockGeminiCredentialsPresent = true
        
        // Even if init timestamps are equal (favoring Claude by default old logic),
        // the new logic should see Claude Session 0 vs Gemini 50 => Show Gemini.
        
        let displayItem = vm.activeDisplayItem
        
        #expect(displayItem != nil)
        #expect(displayItem?.icon == "sparkle", "Should show Gemini icon (sparkle) but showed \(displayItem?.icon ?? "nil")")
        #expect(displayItem?.text == "50%", "Should show Gemini usage")
    }

    @MainActor
    @Test("Prioritize Claude when Gemini is 0 and Claude is active")
    func prioritizeClaudeOverInactiveGemini() {
        // Setup Claude: Session 50%
        let claudeUsage = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 50.0, resetsAt: Date()),
            sevenDay: UsageWindow(utilization: 10.0, resetsAt: Date())
        )
        
        // Setup Gemini: Usage 0% (100% remaining)
        let geminiUsage = GeminiUsage(
            buckets: [
                GeminiModelUsage(
                    modelId: "gemini-1.5-pro",
                    tokenType: "REQUESTS",
                    remainingAmount: "100",
                    remainingFraction: 1.0,
                    resetTime: ISO8601DateFormatter().string(from: Date())
                )
            ],
            lastUpdated: Date()
        )
        
        let vm = UsageViewModel(
            webUsage: claudeUsage,
            geminiUsage: geminiUsage,
            isClaudeEnabled: true,
            isGeminiEnabled: true
        )
        vm.sessionKey = "test"
        vm.organizationId = "test"
        vm._mockGeminiCredentialsPresent = true
        
        let displayItem = vm.activeDisplayItem
        
        #expect(displayItem != nil)
        #expect(displayItem?.icon == "asterisk", "Should show Claude icon (asterisk)")
        #expect(displayItem?.text == "50%")
    }
}