import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var server: ServerManager
    @Binding var selectedModel: MLXModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                configSection("Model 模型") {
                    if let model = selectedModel {
                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                    .font(.subheadline.bold())
                                Text(model.path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    } else {
                        Label("Select a model from the sidebar 从侧边栏选择模型", systemImage: "arrow.left")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                configSection("Context Length 上下文长度") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(configManager.config.contextLength) },
                                    set: { configManager.config.contextLength = Int($0) }
                                ),
                                in: 2048...131072,
                                step: 2048
                            )
                            Text("\(configManager.config.contextLength)")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                        // Quick presets
                        HStack(spacing: 4) {
                            ForEach([4096, 8192, 16384, 32768, 65536, 131072], id: \.self) { value in
                                Button(action: { configManager.config.contextLength = value }) {
                                    Text(contextLabel(value))
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(configManager.config.contextLength == value
                                                      ? Color.accentColor.opacity(0.2)
                                                      : Color.secondary.opacity(0.1))
                                        )
                                        .foregroundColor(configManager.config.contextLength == value
                                                         ? .accentColor : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Higher values use more memory 值越大占用内存越多")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                configSection("Port 端口") {
                    HStack {
                        TextField("Port 端口", value: $configManager.config.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("默认: 8000")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                configSection("Model Type 模型类型") {
                    Picker("", selection: $configManager.config.modelType) {
                        ForEach(ServerConfig.ModelType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                configSection("Python 环境") {
                    HStack {
                        TextField("Python 路径", text: $configManager.config.pythonPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        Button("Browse 浏览") {
                            browseForPython()
                        }
                        .font(.caption)
                    }
                }

                if let model = selectedModel {
                    configSection("Memory Estimate 内存预估") {
                        let modelGB = Double(model.size) / 1_073_741_824
                        let contextGB = configManager.config.estimatedMemoryGB
                        let totalGB = modelGB + contextGB

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Model 模型:")
                                Spacer()
                                Text(String(format: "%.1f GB", modelGB))
                            }
                            HStack {
                                Text("Context 上下文 (~预估):")
                                Spacer()
                                Text(String(format: "%.1f GB", contextGB))
                            }
                            Divider()
                            HStack {
                                Text("Total 总计 (预估):")
                                    .bold()
                                Spacer()
                                Text(String(format: "~%.1f GB", totalGB))
                                    .bold()
                                    .foregroundColor(totalGB > 16 ? .red : .primary)
                            }
                        }
                        .font(.caption)
                    }
                }

                configSection("API Endpoint 端点") {
                    HStack {
                        Text(configManager.config.apiURL)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: copyAPIURL) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy API URL 复制 API 地址")
                    }
                }
            }
            .padding(16)
        }
    }

    private func configSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func copyAPIURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configManager.config.apiURL, forType: .string)
    }

    private func contextLabel(_ value: Int) -> String {
        if value >= 1024 {
            return "\(value / 1024)K"
        }
        return "\(value)"
    }

    private func browseForPython() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        if panel.runModal() == .OK, let url = panel.url {
            configManager.config.pythonPath = url.path
        }
    }
}
