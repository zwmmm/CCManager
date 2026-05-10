import AppKit
import SwiftUI

struct UsageStatsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var usageManager: UsageStatsManager

    @State private var summaryAggregation: UsageAggregation = .day
    @State private var sessionAggregation: UsageSessionAggregation = .all
    @State private var isAppearing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            switch usageManager.state {
            case .idle, .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .loaded(let report):
                reportView(report)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background)
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 6)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.84).delay(0.04)) {
                isAppearing = true
            }
            usageManager.refreshIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(themeManager.brandColor)

                    Text("Usage Statistics")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Text("ccusage + @ccusage/codex")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            Button {
                usageManager.refresh()
            } label: {
                Label(usageManager.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(SecondaryDashboardButtonStyle())
            .disabled(usageManager.isRefreshing)
        }
    }

    private func reportView(_ report: UsageReport) -> some View {
        let buckets = UsageStatsAggregator.aggregate(report.entries, by: summaryAggregation)
        let visibleBuckets = Array(buckets.reversed())
        let sessionBuckets = UsageStatsAggregator.sessionBuckets(report.sessions, by: sessionAggregation)

        return VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                UsageMetricCard(title: "Total", value: UsageValueFormatter.tokenCount(report.summary.totalTokens), symbol: "sum", accent: themeManager.brandColor)
                UsageMetricCard(title: "Input", value: UsageValueFormatter.tokenCount(report.summary.inputTokens), symbol: "arrow.down.left", accent: .blue)
                UsageMetricCard(title: "Output", value: UsageValueFormatter.tokenCount(report.summary.outputTokens), symbol: "arrow.up.right", accent: .orange)
                UsageMetricCard(title: "Cost", value: UsageValueFormatter.currencyUSD(report.summary.totalCostUSD), symbol: "dollarsign", accent: .green)
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Summary", trailing: summaryAggregationPicker)

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleBuckets) { bucket in
                                UsageBucketRow(bucket: bucket, accent: themeManager.brandColor)
                                if bucket.id != visibleBuckets.last?.id {
                                    Rectangle()
                                        .fill(AppTheme.separator)
                                        .frame(height: 1)
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .background(AppTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                }
            }
            .usagePanel()
            .frame(maxHeight: sessionBuckets.isEmpty ? .infinity : 220)

            if false && !sessionBuckets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Top Sessions", trailing: sessionAggregationPicker)

                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(sessionBuckets) { bucket in
                                    UsageSessionBucketHeader(label: bucket.label)
                                    ForEach(bucket.sessions) { session in
                                        UsageSessionRow(session: session, accent: themeManager.brandColor) {
                                            usageManager.openSession(session)
                                        }
                                        if session.id != bucket.sessions.last?.id {
                                            Rectangle()
                                                .fill(AppTheme.separator)
                                                .frame(height: 1)
                                                .padding(.horizontal, 12)
                                        }
                                    }
                                    if bucket.id != sessionBuckets.last?.id {
                                        Rectangle()
                                            .fill(AppTheme.cardStroke)
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .background(AppTheme.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    }
                }
                .usagePanel()
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var summaryAggregationPicker: some View {
        HStack(spacing: 4) {
            ForEach(UsageAggregation.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        summaryAggregation = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(summaryAggregation == item ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(summaryAggregation == item ? themeManager.brandColor : AppTheme.subtleFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sessionAggregationPicker: some View {
        HStack(spacing: 4) {
            ForEach(UsageSessionAggregation.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        sessionAggregation = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(sessionAggregation == item ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(sessionAggregation == item ? themeManager.brandColor : AppTheme.subtleFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(themeManager.brandColor)

            Text("Loading usage data...")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .frame(maxHeight: .infinity, alignment: .top)
        .usagePanel()
    }

    private func errorView(_ message: String) -> some View {
        installStateView(
            symbol: "exclamationmark.triangle",
            title: "Could not load usage",
            message: message,
            command: "npx --yes ccusage@latest daily --json --offline"
        )
    }

    private func installStateView(symbol: String, title: String, message: String, command: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(themeManager.brandColor)
                .frame(width: 54, height: 54)
                .background(themeManager.brandColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: 10) {
                Text(command)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(SecondaryDashboardButtonStyle())
                .help("Copy command")
            }

            Button {
                usageManager.refresh()
            } label: {
                Label("Check Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 130)
            }
            .buttonStyle(PrimaryDashboardButtonStyle(accent: themeManager.brandColor))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .usagePanel()
    }

    private func sectionHeader<Trailing: View>(_ title: String, trailing: Trailing) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            trailing
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        sectionHeader(title, trailing: EmptyView())
    }
}

private struct UsageMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 22)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(12)
        .frame(minHeight: 88, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [AppTheme.cardFill, accent.opacity(isHovering ? 0.10 : 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovering ? accent.opacity(0.32) : AppTheme.cardStroke, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: isHovering ? accent.opacity(0.10) : Color.clear, radius: 10, x: 0, y: 6)
        .offset(y: isHovering ? -1 : 0)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct UsageBucketRow: View {
    let bucket: UsageBucket
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(bucket.label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 92, alignment: .leading)

            UsageTokenChip(title: "Total", value: UsageValueFormatter.tokenCount(bucket.totalTokens), accent: accent)
            UsageTokenChip(title: "In", value: UsageValueFormatter.tokenCount(bucket.inputTokens), accent: .blue)
            UsageTokenChip(title: "Out", value: UsageValueFormatter.tokenCount(bucket.outputTokens), accent: .orange)

            Spacer(minLength: 8)

            Text(UsageValueFormatter.currencyUSD(bucket.costUSD))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct UsageSessionBucketHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(AppTheme.textTertiary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

private struct UsageSessionRow: View {
    let session: UsageSessionEntry
    let accent: Color
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(session.source.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(session.source == .codex ? .purple : accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill((session.source == .codex ? Color.purple : accent).opacity(0.10))
                            )

                        Text(session.lastActivity)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    Text(session.displayName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(session.models.prefix(2).joined(separator: " / "))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 10)

                UsageTokenChip(title: "Total", value: UsageValueFormatter.tokenCount(session.totalTokens), accent: accent)
                UsageTokenChip(title: "Cache", value: UsageValueFormatter.tokenCount(session.cacheTokens), accent: .teal)

                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isHovering ? accent : AppTheme.textTertiary)
                    .frame(width: 18)

                Text(UsageValueFormatter.currencyUSD(session.costUSD))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 74, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovering ? accent.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Open session in terminal")
    }
}

private struct UsageTokenChip: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent.opacity(0.9))
                .frame(width: 5, height: 5)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        }
    }
}

private extension View {
    func usagePanel() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.cardFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: AppTheme.shadow.opacity(0.7), radius: 12, x: 0, y: 8)
    }
}
