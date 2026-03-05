import SwiftUI

struct StatusView: View {
    @EnvironmentObject var server: ServerManager
    @EnvironmentObject var configManager: ConfigManager
    @State private var uptimeText = "--"
    @State private var refreshTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard

                if server.status.isRunning {
                    infoCard
                }

                actionsCard
            }
            .padding(16)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            uptimeText = server.uptime
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SERVER STATUS 服务状态")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: statusColor.opacity(0.5), radius: 4)

                VStack(alignment: .leading) {
                    Text(server.status.displayText)
                        .font(.title3.bold())
                    if let model = server.currentModel {
                        Text(model)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DETAILS 详情")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                infoRow("Port 端口", value: "\(configManager.config.port)")
                infoRow("Uptime 运行时间", value: uptimeText)
                infoRow("Memory 内存", value: server.memoryUsageMB > 0 ? String(format: "%.0f MB", server.memoryUsageMB) : "Measuring 测量中...")
                infoRow("Health 健康", value: server.isHealthy ? "✓ Healthy 健康" : "Checking 检查中...")
                infoRow("API 地址", value: configManager.config.apiURL)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    @State private var copiedFeedback: String?

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS 快捷操作")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Button(action: {
                    copyAPIURL()
                    showCopied("API URL")
                }) {
                    Label("Copy API URL 复制地址", systemImage: "doc.on.doc")
                        .font(.caption)
                }

                Button(action: {
                    copyCurlCommand()
                    showCopied("cURL")
                }) {
                    Label("Copy cURL 复制命令", systemImage: "terminal")
                        .font(.caption)
                }

                if let feedback = copiedFeedback {
                    Text("\(feedback) copied 已复制!")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Spacer()
            }
        }
    }

    private func showCopied(_ label: String) {
        withAnimation { copiedFeedback = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedFeedback = nil }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
            Spacer()
        }
    }

    private var statusColor: Color {
        switch server.status {
        case .running: return .green
        case .starting: return .orange
        case .error: return .red
        case .stopped: return .gray
        }
    }

    private func copyAPIURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configManager.config.apiURL, forType: .string)
    }

    private func copyCurlCommand() {
        let curl = """
curl \(configManager.config.apiURL)/chat/completions \\
  -H "Content-Type: application/json" \\
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello"}]}'
"""
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(curl, forType: .string)
    }
}
