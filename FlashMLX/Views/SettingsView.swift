import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Launch at Login
                settingsSection("General") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            toggleLaunchAtLogin(newValue)
                        }

                    Text("Start FlashMLX automatically when you log in")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Python Environment
                settingsSection("Python Environment") {
                    HStack {
                        TextField("Python path", text: $configManager.config.pythonPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        Button("Browse") {
                            browseForPython()
                        }
                        .font(.caption)
                    }

                    Button("Verify Python") {
                        verifyPython()
                    }
                    .font(.caption)

                    if let result = pythonVerifyResult {
                        Text(result)
                            .font(.caption2)
                            .foregroundColor(pythonVerifySuccess ? .green : .red)
                    }
                }

                // Default Server Settings
                settingsSection("Default Server Settings") {
                    HStack {
                        Text("Default Port:")
                            .font(.caption)
                        TextField("Port", value: $configManager.config.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Default Context:")
                            .font(.caption)
                        Text("\(configManager.config.contextLength)")
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                // About
                settingsSection("About") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("FlashMLX")
                                .font(.subheadline.bold())
                            Text("v1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("Lightweight MLX Model Launcher for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Reset
                settingsSection("Danger Zone") {
                    Button("Reset All Settings", role: .destructive) {
                        showResetAlert = true
                    }
                    .font(.caption)
                }
            }
            .padding(16)
        }
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                configManager.config = ServerConfig()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to defaults. This cannot be undone.")
        }
    }

    @State private var pythonVerifyResult: String?
    @State private var pythonVerifySuccess = false
    @State private var showResetAlert = false

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
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

    private func verifyPython() {
        let path = (configManager.config.pythonPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            pythonVerifyResult = "✗ Python not found at \(path)"
            pythonVerifySuccess = false
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["-c", "import mlx_lm; print(f'mlx-lm {mlx_lm.__version__}')"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if proc.terminationStatus == 0 {
                pythonVerifyResult = "✓ \(output)"
                pythonVerifySuccess = true
            } else {
                pythonVerifyResult = "✗ mlx-lm not installed. Run: \(path) -m pip install mlx-lm"
                pythonVerifySuccess = false
            }
        } catch {
            pythonVerifyResult = "✗ \(error.localizedDescription)"
            pythonVerifySuccess = false
        }
    }
}
