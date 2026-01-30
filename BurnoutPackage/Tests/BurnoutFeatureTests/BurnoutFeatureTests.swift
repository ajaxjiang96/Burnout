import Testing
import Foundation
@testable import BurnoutFeature

@Suite("UsageViewModel Tests")
struct UsageViewModelTests {

    @MainActor
    @Test("Default state has zero usage and no credentials")
    func defaultState() {
        let viewModel = UsageViewModel(webUsage: nil)

        #expect(viewModel.webUsage == nil)
        #expect(viewModel.geminiUsage == nil)
        #expect(viewModel.usagePercentage == 0)
        #expect(viewModel.error == nil)
        #expect(viewModel.sessionResetText == "")
        #expect(viewModel.weeklyResetText == "")
    }

    @MainActor
    @Test("Claude percentage uses max utilization")
    func claudePercentage() {
        // Case 1: Session is higher
        let sessionHigher = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 60.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 30.0, resetsAt: nil)
        )
        let vm1 = UsageViewModel(webUsage: sessionHigher)
        #expect(vm1.claudePercentage == 0.6)

        // Case 2: Weekly is higher
        let weeklyHigher = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 40.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 80.0, resetsAt: nil)
        )
        let vm2 = UsageViewModel(webUsage: weeklyHigher)
        #expect(vm2.claudePercentage == 0.8)
    }

    @MainActor
    @Test("Display Item Logic - Claude Only")
    func displayItemClaude() {
        // Normal case: Session < 100%
        let normalUsage = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 45.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 10.0, resetsAt: nil)
        )
        let vm = UsageViewModel(webUsage: normalUsage, isGeminiEnabled: false)
        vm.isClaudeEnabled = true
        vm.sessionKey = "dummy"
        vm.organizationId = "dummy"
        
        guard let item = vm.activeDisplayItem else {
            #expect(Bool(false), "Display item should not be nil")
            return
        }
        
        #expect(item.icon == "asterisk")
        #expect(item.text == "45%")
    }
    
    @MainActor
    @Test("Display Item Logic - Claude Weekly High")
    func displayItemClaudeWeeklyHigh() {
        // Weekly > 95% -> Should show weekly
        let highWeekly = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 10.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 96.0, resetsAt: nil)
        )
        let vm = UsageViewModel(webUsage: highWeekly, isGeminiEnabled: false)
        vm.isClaudeEnabled = true
        vm.sessionKey = "dummy"
        vm.organizationId = "dummy"
        
        guard let item = vm.activeDisplayItem else {
            #expect(Bool(false), "Display item should not be nil")
            return
        }
        
        #expect(item.text == "96%")
    }

    @MainActor
    @Test("Display Item Logic - Gemini Only")
    func displayItemGemini() {
        let usage = GeminiUsage(
            buckets: [
                GeminiModelUsage(
                    modelId: "gemini-1.5-pro",
                    tokenType: "REQUESTS",
                    remainingAmount: "100",
                    remainingFraction: 0.25, // 25% remaining -> 75% used
                    resetTime: "2024-01-01T00:00:00Z"
                )
            ],
            lastUpdated: Date()
        )
        
        let vm = UsageViewModel(webUsage: nil, geminiUsage: usage, isClaudeEnabled: false, isGeminiEnabled: true)
        vm._mockGeminiCredentialsPresent = true
        
        guard let item = vm.activeDisplayItem else {
            #expect(Bool(false), "Display item should not be nil")
            return
        }
        
        #expect(item.icon == "")
        // Usage is (1 - 0.25) * 100 = 75%
        #expect(item.text == "75%")
    }
}