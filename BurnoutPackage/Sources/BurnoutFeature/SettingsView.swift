import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showingHelp = false

    public init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                TextField(
                    "Organization ID", text: $viewModel.organizationId,
                    prompt: Text("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
                )
                .font(.system(.body, design: .monospaced))

                SecureField("Session Key", text: $viewModel.sessionKey, prompt: Text("sk-ant-..."))
                    .font(.system(.body, design: .monospaced))

            } header: {
                HStack {
                    Text("Claude.ai Credentials")
                    Spacer()
                    Button(action: { showingHelp.toggle() }) {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingHelp) {
                        helpView
                    }
                }
            } footer: {
                if viewModel.hasCredentials {
                    Label("Credentials saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Text("Both fields are required to fetch usage data.")
                        .font(.caption)
                }
            }
            Section("Menu Bar") {
                Picker("Icon style", selection: $viewModel.menuBarIcon) {
                    ForEach(MenuBarIcon.allCases) { style in
                        Label {
                            Text(style.rawValue)
                        } icon: {
                            Image(systemName: style.iconName(for: 0.5))
                        }
                        .tag(style)
                    }
                }
                Picker("Show percentage", selection: $viewModel.displayedUsage) {
                    ForEach(DisplayedUsage.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            }
            Section("About") {
                LabeledContent("Version") {
                    Text(Self.appVersion)
                }
                LabeledContent("Copyright") {
                    Text("© 2026 Jiacheng Jiang")
                }
                LabeledContent("License") {
                    Text("GPL-3.0")
                }
                LabeledContent("GitHub") {
                    Link("ajaxjiang96/Burnout", destination: URL(string: "https://github.com/ajaxjiang96/Burnout")!)
                }
                HStack {
                    Spacer()
                    Link(destination: URL(string: "https://buymeacoffee.com/ajaxjiang")!) {
                        Image("bmc-button")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 420)
    }

    private static var appVersion: String {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var helpView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to get credentials")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HelpStep(number: 1, text: "Go to claude.ai/settings/usage in your browser")
                HelpStep(number: 2, text: "Open Developer Tools (Cmd+Option+I)")
                HelpStep(number: 3, text: "Go to Network tab and refresh the page")
                HelpStep(
                    number: 4, text: "Find the 'usage' request, copy the UUID from the URL path")
                HelpStep(number: 5, text: "Go to Application > Cookies > claude.ai")
                HelpStep(number: 6, text: "Copy the 'sessionKey' value")
            }

            Text("Note: Session keys expire periodically and will need to be updated.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 320)
    }
}

// MARK: - Components

private struct HelpStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Previews

#Preview("Settings - Empty") {
    SettingsView(viewModel: UsageViewModel(webUsage: nil))
}

#Preview("Settings - Configured") {
    SettingsView(
        viewModel: {
            let vm = UsageViewModel(webUsage: nil)
            vm.organizationId = "abcd1234-5678-9abc-def0-123456789abc"
            vm.sessionKey = "sk-ant-example-key"
            return vm
        }())
}
