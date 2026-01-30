import Testing
@testable import BurnoutFeature

@Suite("UsageViewModel Tests")
struct UsageViewModelTests {

    @MainActor
    @Test("Default state has zero usage and no credentials")
    func defaultState() {
        let viewModel = UsageViewModel(webUsage: nil)

        #expect(viewModel.webUsage == nil)
        #expect(viewModel.usagePercentage == 0)
        #expect(viewModel.error == nil)
        #expect(viewModel.sessionResetText == "")
        #expect(viewModel.weeklyResetText == "")
    }

    @MainActor
    @Test("Usage percentage reflects session window in session mode")
    func usagePercentageSession() {
        let usage = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 60.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 30.0, resetsAt: nil)
        )
        let viewModel = UsageViewModel(webUsage: usage)
        viewModel.displayedUsage = .session

        #expect(viewModel.usagePercentage == 0.6)
    }

    @MainActor
    @Test("Usage percentage reflects weekly window in weekly mode")
    func usagePercentageWeekly() {
        let usage = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 60.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 30.0, resetsAt: nil)
        )
        let viewModel = UsageViewModel(webUsage: usage)
        viewModel.displayedUsage = .weekly

        #expect(viewModel.usagePercentage == 0.3)
    }

    @MainActor
    @Test("Usage percentage uses max utilization in highest mode")
    func usagePercentageHighest() {
        let usage = ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 40.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 80.0, resetsAt: nil)
        )
        let viewModel = UsageViewModel(webUsage: usage)
        viewModel.displayedUsage = .highest

        #expect(viewModel.usagePercentage == 0.8)
    }

    @MainActor
    @Test("Menu bar icon changes at usage thresholds for flame style")
    func menuBarIconFlame() {
        let low = UsageViewModel(webUsage: ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 20.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 10.0, resetsAt: nil)
        ))
        low.displayedUsage = .session
        low.selectedIcon = .flame
        #expect(low.menuBarIconName == "flame")

        let mid = UsageViewModel(webUsage: ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 70.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 10.0, resetsAt: nil)
        ))
        mid.displayedUsage = .session
        mid.selectedIcon = .flame
        #expect(mid.menuBarIconName == "flame.fill")

        let high = UsageViewModel(webUsage: ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 95.0, resetsAt: nil),
            sevenDay: UsageWindow(utilization: 10.0, resetsAt: nil)
        ))
        high.displayedUsage = .session
        high.selectedIcon = .flame
        #expect(high.menuBarIconName == "exclamationmark.triangle.fill")
    }
}
