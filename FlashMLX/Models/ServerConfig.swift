import Foundation

struct ServerConfig: Codable {
    var modelPath: String = ""
    var modelType: ModelType = .lm
    var contextLength: Int = 4096
    var port: Int = 8000
    var pythonPath: String = "~/mlx-env/bin/python3"

    enum ModelType: String, Codable, CaseIterable {
        case lm = "lm"
        case multimodal = "multimodal"

        var displayName: String {
            switch self {
            case .lm: return "Language Model"
            case .multimodal: return "Multimodal"
            }
        }
    }

    var apiURL: String {
        "http://localhost:\(port)/v1"
    }

    var estimatedMemoryGB: Double {
        let contextMemoryGB = Double(contextLength) / 4096.0 * 0.5
        return contextMemoryGB
    }
}
