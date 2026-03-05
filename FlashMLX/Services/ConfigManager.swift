import Foundation
import Combine

class ConfigManager: ObservableObject {
    @Published var config: ServerConfig {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let configKey = "FlashMLX.ServerConfig"

    init() {
        if let data = defaults.data(forKey: configKey),
           let saved = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = ServerConfig()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }

    func updateModelPath(_ path: String) {
        config.modelPath = path
    }
}
