import SwiftUI

public struct StatusView: View {
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

            if let usage = viewModel.webUsage {
                usageContent(usage)
            } else if viewModel.hasCredentials {
                ProgressView()
                    .padding()
            } else {
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
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Open Settings to configure your Claude.ai credentials.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var footerButtons: some View {
        HStack {
            SettingsLink {
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
