import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showingHelp = false

    public init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
            }
            
            Section("Appearance") {
                Picker("Menu Bar Icon", selection: $viewModel.selectedIcon) {
                    ForEach(MenuBarIcon.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
            
            Section("AI Services") {
                // MARK: Claude.ai
                Toggle("Claude.ai", isOn: $viewModel.isClaudeEnabled)
                
                if viewModel.isClaudeEnabled {
                    Group {
                        TextField(
                            "Organization ID", text: $viewModel.organizationId,
                            prompt: Text("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
                        )
                        .font(.system(.body, design: .monospaced))

                        SecureField("Session Key", text: $viewModel.sessionKey, prompt: Text("sk-ant-..."))
                            .font(.system(.body, design: .monospaced))
                        
                        HStack {
                            if viewModel.hasClaudeCredentials {
                                Label("Connected", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Setup required", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Button("Get Help") { showingHelp.toggle() }
                                .buttonStyle(.link)
                        }
                        .font(.caption)
                    }
                    .padding(.leading)
                }
                
                // MARK: Gemini
                Toggle("Gemini CLI", isOn: $viewModel.isGeminiEnabled)
                
                if viewModel.isGeminiEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if viewModel.hasGeminiCredentials {
                                Label("Connected", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Not authenticated", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                            Button("Setup Info") { showingHelp.toggle() }
                                .buttonStyle(.link)
                        }
                        
                        if !viewModel.hasGeminiCredentials {
                            Text("Run 'gemini auth login' in your terminal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.leading)
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
            Text("Claude.ai Credentials")
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
            
            Divider()
            
            Text("Gemini CLI Setup")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Authenticate with Gemini CLI:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("gemini auth login")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
                    .textSelection(.enabled)
                
                Text("This creates the necessary credentials file.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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