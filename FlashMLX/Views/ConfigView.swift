import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var server: ServerManager
    @Binding var selectedModel: MLXModel?
    @State private var sliderValue: Double = 4096

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                configSection("Model") {
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
                        Label("Select a model from the sidebar", systemImage: "arrow.left")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                configSection("Context Length") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Slider(value: $sliderValue, in: 2048...131072, step: 2048) { editing in
                                if !editing {
                                    configManager.config.contextLength = Int(sliderValue)
                                }
                            }
                            Text("\(Int(sliderValue))")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                        HStack(spacing: 4) {
                            ForEach([4096, 8192, 16384, 32768, 65536, 131072], id: \.self) { value in
                                Button(action: {
                                    sliderValue = Double(value)
                                    configManager.config.contextLength = value
                                }) {
                                    Text(contextLabel(value))
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Int(sliderValue) == value
                                                      ? Color.accentColor.opacity(0.2)
                                                      : Color.secondary.opacity(0.1))
                                        )
                                        .foregroundColor(Int(sliderValue) == value
                                                         ? .accentColor : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Higher values use more memory")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .onAppear { sliderValue = Double(configManager.config.contextLength) }
                }

                configSection("Port") {
                    HStack {
                        TextField("Port", value: $configManager.config.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("Default: 8000")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                configSection("Model Type") {
                    HStack {
                        Image(systemName: configManager.config.modelType == .multimodal ? "eye" : "text.bubble")
                            .foregroundColor(.secondary)
                        Text(configManager.config.modelType.displayName)
                            .font(.subheadline)
                        Text("(Auto-detected)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                configSection("Python") {
                    HStack {
                        TextField("Python Path", text: $configManager.config.pythonPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        Button("Browse") {
                            browseForPython()
                        }
                        .font(.caption)
                    }
                }

                if let model = selectedModel {
                    configSection("Memory Estimate") {
                        let modelGB = Double(model.size) / 1_073_741_824
                        let contextGB = configManager.config.estimatedMemoryGB
                        let totalGB = modelGB + contextGB

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Model:")
                                Spacer()
                                Text(String(format: "%.1f GB", modelGB))
                            }
                            HStack {
                                Text("Context:")
                                Spacer()
                                Text(String(format: "%.1f GB", contextGB))
                            }
                            Divider()
                            HStack {
                                Text("Total:")
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

                configSection("API") {
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
                        .help("Copy")
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
