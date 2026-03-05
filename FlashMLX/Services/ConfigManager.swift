import Foundation
import Combine

class ConfigManager: ObservableObject {
    @Published var config: ServerConfig {
        didSet { debounceSave() }
    }

    private let defaults = UserDefaults.standard
    private let configKey = "FlashMLX.ServerConfig"
    private var saveTimer: Timer?

    init() {
        if let data = defaults.data(forKey: configKey),
           let saved = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            _config = Published(initialValue: saved)
        } else {
            _config = Published(initialValue: ServerConfig())
        }
    }

    private func debounceSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.save()
        }
    }

    func save() {
        saveTimer?.invalidate()
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }

    func updateModelPath(_ path: String) {
        config.modelPath = path
    }
}
