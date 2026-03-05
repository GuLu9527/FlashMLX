import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var scanner: ModelScanner
    @EnvironmentObject var server: ServerManager
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedTab: Tab = .config
    @State private var selectedModel: MLXModel?

    enum Tab: String, CaseIterable {
        case config = "Config 配置"
        case status = "Status 状态"
        case logs = "Logs 日志"
        case download = "Download 下载"
        case settings = "Settings 设置"

        var icon: String {
            switch self {
            case .config: return "slider.horizontal.3"
            case .status: return "heart.text.square"
            case .logs: return "doc.text"
            case .download: return "arrow.down.circle"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            HStack(spacing: 0) {
                ModelListView(selectedModel: $selectedModel)
                    .frame(width: 200)

                Divider()

                VStack(spacing: 0) {
                    tabBar
                    Divider()

                    Group {
                        switch selectedTab {
                        case .config:
                            ConfigView(selectedModel: $selectedModel)
                        case .status:
                            StatusView()
                        case .logs:
                            LogView()
                        case .download:
                            DownloadView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 680, height: 480)
        .onChange(of: selectedModel) { _, newValue in
            if let model = newValue {
                configManager.config.modelPath = model.path
            }
        }
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .font(.title2)
            Text("FlashMLX")
                .font(.headline)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(server.status.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: toggleServer) {
                Label(
                    server.status.isRunning ? "Stop 停止" : "Start 启动",
                    systemImage: server.status.isRunning ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(server.status.isRunning ? .red : .green)
            .controlSize(.small)
            .disabled(configManager.config.modelPath.isEmpty)

            Button(action: {
                AppDelegate.shared.detachToWindow()
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Detach to window 拆卸为窗口")

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Quit 退出 FlashMLX")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } }) {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch server.status {
        case .running: return .green
        case .starting: return .orange
        case .error: return .red
        case .stopped: return .gray
        }
    }

    private func toggleServer() {
        if server.status.isRunning {
            server.stop()
        } else {
            server.start(config: configManager.config)
        }
    }
}
