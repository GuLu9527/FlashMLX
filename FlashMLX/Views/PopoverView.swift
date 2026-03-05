import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var scanner: ModelScanner
    @EnvironmentObject var server: ServerManager
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedTab: Tab = .config
    @State private var selectedModel: MLXModel?

    enum Tab: String, CaseIterable {
        case config = "Config"
        case status = "Status"
        case logs = "Logs"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .config: return "slider.horizontal.3"
            case .status: return "heart.text.square"
            case .logs: return "doc.text"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            NavigationSplitView {
                ModelListView(selectedModel: $selectedModel)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } detail: {
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
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onChange(of: selectedModel) { _, newValue in
            if let model = newValue {
                configManager.config.modelPath = model.path
                configManager.config.modelType = model.detectedModelType
            }
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

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(server.status.displayText)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: toggleServer) {
                Label(
                    server.status.isRunning ? "Stop" : "Start",
                    systemImage: server.status.isRunning ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(server.status.isRunning ? .red : .green)
            .controlSize(.small)
            .disabled(configManager.config.modelPath.isEmpty)

            Button(action: { AppDelegate.shared.detachToWindow() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Detach to window")

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } }) {
                    Label(LocalizedStringKey(tab.rawValue), systemImage: tab.icon)
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
