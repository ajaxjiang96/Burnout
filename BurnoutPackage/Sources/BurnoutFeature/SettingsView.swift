import SwiftUI
import AppKit

public struct SettingsView: View {
    var viewModel: UsageViewModel

    public init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            GeneralSettingsView(viewModel: viewModel)
            AIServicesSettingsView(viewModel: viewModel)
            AboutSettingsView(viewModel: viewModel)
            DisclaimerSettingsView()
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 500)
    }
}

// MARK: - Subviews

private struct DisclaimerSettingsView: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Disclaimer", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                
                Text("Burnout is an unofficial project and is not affiliated with Anthropic or Google.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("This app uses internal APIs which may violate Terms of Service. Use at your own risk. The developer is not responsible for any account actions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct GeneralSettingsView: View {
    @Bindable var viewModel: UsageViewModel
    
    var body: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
            Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar Display Logic")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                Text("• Displays the most recently updated service.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("• Claude: Session usage (Weekly if > 95%).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("• Gemini: Pro model usage.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

private struct AIServicesSettingsView: View {
    @Bindable var viewModel: UsageViewModel
    @State private var showClaudeHelp = false
    @State private var showGeminiHelp = false
    
    var body: some View {
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
                        Button {
                            withAnimation { showClaudeHelp.toggle() }
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show setup instructions")
                    }
                    .font(.caption)
                    
                    if showClaudeHelp {
                        ClaudeHelpInstructions()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
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
                        Button {
                            withAnimation { showGeminiHelp.toggle() }
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show setup instructions")
                    }
                    .font(.caption)
                    
                    if !viewModel.hasGeminiCredentials && !showGeminiHelp {
                        Text("Run 'gemini auth login' in your terminal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if showGeminiHelp {
                        GeminiHelpInstructions()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.leading)
            }
        }
    }
}

private struct ClaudeHelpInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to find your credentials:")
                .font(.caption)
                .bold()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Go to claude.ai/settings/usage")
                Text("2. Open Developer Tools (Cmd+Option+I)")
                Text("3. Check Network tab > 'usage' request")
                Text("4. UUID from URL path = Organization ID")
                Text("5. Application > Cookies > 'sessionKey'")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

private struct GeminiHelpInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Authenticate with Gemini CLI:")
                .font(.caption)
                .bold()
            
            HStack {
                Text("gemini auth login")
                    .font(.system(.caption, design: .monospaced))
                
                Spacer()
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("gemini auth login", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Copy command")
            }
            .padding(8)
            .background(Color.black.opacity(0.1))
            .cornerRadius(4)
            
            Text("This creates the necessary credentials file.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

private struct AboutSettingsView: View {
    var viewModel: UsageViewModel

    var body: some View {
        Section("About") {
            LabeledContent("Version", value: SettingsView.appVersion)
            
            LabeledContent("Update") {
                if let release = viewModel.latestRelease, let url = URL(string: release.htmlUrl) {
                    Link("Available: \(release.tagName)", destination: url)
                        .foregroundStyle(.blue)
                } else {
                    Button("Check for Updates") {
                        viewModel.checkForUpdates()
                    }
                    .buttonStyle(.link)
                }
            }
            
            LabeledContent("Copyright", value: "© 2026 Jiacheng Jiang")
            LabeledContent("License", value: "GPL-3.0")
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
}

extension SettingsView {
    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
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