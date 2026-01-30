import SwiftUI

public struct StatusView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: UsageViewModel

    public init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: 16) {
                    errorView
                    
                    if viewModel.isClaudeEnabled {
                        claudeSection
                    }
                    
                    if viewModel.isGeminiEnabled {
                        geminiSection
                    }
                    
                    if !viewModel.hasCredentials {
                        emptyState
                    }
                }
                .padding(.vertical, 16)
            }

            Divider()
            footer
        }
        .frame(width: 320)
        .frame(maxHeight: 800)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Burnout Status")
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Refresh quotas")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.error {
            Text(error)
                .foregroundColor(.red)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var claudeSection: some View {
        if let usage = viewModel.webUsage {
            UsageSection(title: "Claude Code Quota", systemImage: "bolt.fill") {
                HStack(spacing: 24) {
                    UsageGauge(
                        title: "Session (5h)",
                        percentage: usage.fiveHour.utilization,
                        resetText: viewModel.sessionResetText,
                        viewModel: viewModel
                    )
                    UsageGauge(
                        title: "Weekly (7d)",
                        percentage: usage.sevenDay.utilization,
                        resetText: viewModel.weeklyResetText,
                        viewModel: viewModel
                    )
                }
                .frame(maxWidth: .infinity)
            }
        } else if viewModel.hasClaudeCredentials {
            loadingCard(title: "Claude Code")
        }
    }

    @ViewBuilder
    private var geminiSection: some View {
        if let usage = viewModel.geminiUsage {
            UsageSection(title: "Gemini CLI Quota", systemImage: "sparkles") {
                VStack(spacing: 12) {
                    ForEach(usage.buckets) { bucket in
                        GeminiUsageRow(bucket: bucket, viewModel: viewModel)
                    }
                }
            }
        } else if viewModel.hasGeminiCredentials {
            loadingCard(title: "Gemini CLI")
        }
    }

    private func loadingCard(title: String) -> some View {
        UsageSection(title: title, systemImage: "hourglass") {
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        Button {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("Configure your credentials in Settings to track your usage.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var footer: some View {
        HStack {
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.glass)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.glass)
        }
        .padding(16)
    }
}

// MARK: - Components

struct UsageSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(.secondary)
            .padding(.leading, 4)

            GlassEffectContainer(spacing: 12) {
                content()
                    .padding(12)
            }
        }
        .padding(.horizontal)
    }
}

struct GeminiUsageRow: View {
    let bucket: GeminiModelUsage
    let viewModel: UsageViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.modelId.replacingOccurrences(of: "gemini-", with: ""))
                    .font(.system(size: 12, weight: .semibold))
                
                HStack(spacing: 4) {
                    if let remaining = bucket.remainingAmount {
                        Text("\(remaining) left")
                        Text("•")
                    }
                    Text(formatResetTime(bucket.resetTime))
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(bucket.usagePercentage))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.color(for: bucket.usagePercentage / 100.0))
                
                ProgressView(value: min(bucket.usagePercentage, 100), total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 64)
                    .tint(viewModel.color(for: bucket.usagePercentage / 100.0))
            }
        }
    }

    private func formatResetTime(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate) else {
            return isoDate
        }
        
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 { return "Resetting..." }
        
        let componentFormatter = DateComponentsFormatter()
        componentFormatter.allowedUnits = [.day, .hour, .minute]
        componentFormatter.unitsStyle = .abbreviated
        componentFormatter.maximumUnitCount = 1
        return "in " + (componentFormatter.string(from: diff) ?? "")
    }
}

struct UsageGauge: View {
    let title: String
    let percentage: Double
    let resetText: String
    let viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            Gauge(value: min(percentage, 100), in: 0...100) {
                Text(title)
            } currentValueLabel: {
                Text("\(Int(percentage))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .frame(width: 72, height: 72)
            .tint(viewModel.color(for: percentage / 100.0))
            
            if !resetText.isEmpty {
                Label(resetText, systemImage: "clock")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text(" ")
                    .font(.system(size: 9))
            }
        }
    }
}

// MARK: - Previews

#Preview("With Usage") {
    StatusView(viewModel: UsageViewModel(
        webUsage: ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 32.0, resetsAt: Date().addingTimeInterval(2 * 3600)),
            sevenDay: UsageWindow(utilization: 49.0, resetsAt: Date().addingTimeInterval(3 * 86400))
        )
    ))
}

#Preview("Gemini Usage") {
    StatusView(viewModel: UsageViewModel(
        webUsage: nil,
        geminiUsage: GeminiUsage(
            buckets: [
                GeminiModelUsage(modelId: "gemini-2.0-flash", tokenType: "REQUESTS", remainingAmount: "10", remainingFraction: 0.68, resetTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))),
                GeminiModelUsage(modelId: "gemini-1.5-pro", tokenType: "REQUESTS", remainingAmount: "2", remainingFraction: 0.18, resetTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200)))
            ],
            lastUpdated: Date()
        )
    ))
}

#Preview("Empty State") {
    StatusView(viewModel: UsageViewModel(
        webUsage: nil,
        geminiUsage: nil
    ))
}

#Preview("Error State") {
    StatusView(viewModel: UsageViewModel(
        webUsage: nil,
        error: "Session expired. Please update your session key."
    ))
}
