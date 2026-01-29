import SwiftUI
import BurnoutFeature

@main
struct BurnoutApp: App {
    @StateObject private var viewModel = UsageViewModel()

    init() {
        print("BurnoutApp Launching...")
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
