import SwiftUI

public struct StatusView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: UsageViewModel

    public init(viewModel: UsageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Burnout Status")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if viewModel.isClaudeEnabled {
                if let usage = viewModel.webUsage {
                    usageContent(usage)
                } else if viewModel.hasClaudeCredentials {
                    ProgressView()
                        .padding()
                }
            }
            
            if viewModel.isGeminiEnabled {
                if let gemini = viewModel.geminiUsage {
                    geminiContent(gemini)
                } else if viewModel.hasGeminiCredentials {
                     // Show loader if Gemini is configured and we are waiting
                     ProgressView().padding()
                }
            }

            if !viewModel.hasCredentials {
                emptyState
            }

            Divider()

            footerButtons
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private func usageContent(_ usage: ClaudeWebUsage) -> some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 20) {
                UsageGauge(
                    title: "Session (5h)",
                    percentage: usage.fiveHour.utilization,
                    resetText: viewModel.sessionResetText
                )
                UsageGauge(
                    title: "Weekly (7d)",
                    percentage: usage.sevenDay.utilization,
                    resetText: viewModel.weeklyResetText
                )
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func geminiContent(_ usage: GeminiUsage) -> some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gemini CLI Quota")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ForEach(usage.buckets) { bucket in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bucket.modelId.replacingOccurrences(of: "gemini-", with: ""))
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 4) {
                                if let remaining = bucket.remainingAmount {
                                    Text("\(remaining) left")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(formatResetTime(bucket.resetTime))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(String(format: "%.1f", bucket.usagePercentage))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(color(for: bucket.usagePercentage))
                            
                            ProgressView(value: bucket.usagePercentage, total: 100)
                                .progressViewStyle(.linear)
                                .frame(width: 60)
                                .tint(color(for: bucket.usagePercentage))
                        }
                    }
                }
            }
            .padding(12)
        }
        .padding(.horizontal)
    }
    
    private func formatResetTime(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Try standard ISO8601 first (some APIs return fractional seconds, some don't)
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
    
    private func color(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50: return .green
        case 50..<80: return .yellow
        case 80..<100: return .orange
        default: return .red
        }
    }

    private var emptyState: some View {
        Button {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Open Settings to configure credentials.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .padding()
    }

    private var footerButtons: some View {
        HStack {
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.glass)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.glass)
        }
        .padding()
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

#Preview("High Usage") {
    StatusView(viewModel: UsageViewModel(
        webUsage: ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 95.0, resetsAt: Date().addingTimeInterval(1800)),
            sevenDay: UsageWindow(utilization: 82.0, resetsAt: Date().addingTimeInterval(86400))
        )
    ))
}

#Preview("Gemini Usage") {
    StatusView(viewModel: UsageViewModel(
        webUsage: nil,
        geminiUsage: GeminiUsage(
            buckets: [
                GeminiModelUsage(modelId: "gemini-2.5-flash-lite", tokenType: "REQUESTS", remainingAmount: "4", remainingFraction: 0.023, resetTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))),
                GeminiModelUsage(modelId: "gemini-3-pro-preview", tokenType: "REQUESTS", remainingAmount: "3", remainingFraction: 0.22, resetTime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200)))
            ],
            lastUpdated: Date()
        )
    ))
}

#Preview("Maxed Out") {
    StatusView(viewModel: UsageViewModel(
        webUsage: ClaudeWebUsage(
            fiveHour: UsageWindow(utilization: 100.0, resetsAt: Date().addingTimeInterval(900)),
            sevenDay: UsageWindow(utilization: 100.0, resetsAt: Date().addingTimeInterval(43200))
        )
    ))
}

#Preview("No Credentials") {
    StatusView(viewModel: UsageViewModel(
        webUsage: nil
    ))
}

#Preview("Error State") {
    StatusView(viewModel: UsageViewModel(
        webUsage: nil,
        error: "Session expired. Please update your session key."
    ))
}

#Preview("Gauge - Green") {
    UsageGauge(title: "Session (5h)", percentage: 25.0, resetText: "2h 30m")
        .padding()
}

#Preview("Gauge - Red") {
    UsageGauge(title: "Weekly (7d)", percentage: 100.0, resetText: "12h 15m")
        .padding()
}

// MARK: - Components

struct UsageGauge: View {
    let title: String
    let percentage: Double
    let resetText: String

    var color: Color {
        switch percentage {
        case 0..<50: return .green
        case 50..<80: return .yellow
        case 80..<100: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(min(percentage, 100) / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: percentage)

                Text("\(Int(percentage))%")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 70, height: 70)
            .padding(6)
            .glassEffect(.regular, in: .circle)

            if !resetText.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(resetText)
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            } else {
                Text(" ")
                    .font(.system(size: 10))
            }
        }
    }
}