import SwiftUI
import BurnoutFeature
import os

@main
struct BurnoutApp: App {
    @State private var viewModel = UsageViewModel()
    private static let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "App")

    init() {
        Self.logger.info("BurnoutApp launching")
    }

    var body: some Scene {
        MenuBarExtra {
            StatusView(viewModel: viewModel)
        } label: {
            if let item = viewModel.activeDisplayItem {
                HStack(spacing: 2) {
                    Image(systemName: item.icon)
                        .imageScale(.small)
                    Text(item.text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(item.color)
                }
            } else {
                Image(systemName: "flame")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}