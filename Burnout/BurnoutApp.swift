import SwiftUI
import BurnoutFeature
import os

@main
struct BurnoutApp: App {
    @StateObject private var viewModel = UsageViewModel()
    private static let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "App")

    init() {
        Self.logger.info("BurnoutApp launching")
    }

    var body: some Scene {
        MenuBarExtra {
            StatusView(viewModel: viewModel)
        } label: {
            HStack {
                Image(systemName: viewModel.menuBarIconName)
                if viewModel.usagePercentage > 0.9, let usage = viewModel.webUsage, usage.soonestReset != nil {
                    Text(viewModel.soonestResetText)
                        .foregroundStyle(.red)
                } else {
                    Text("\(Int(viewModel.usagePercentage * 100))%")
                        .font(.system(.body, design: .monospaced))
                }
            }.frame(alignment: .center)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
