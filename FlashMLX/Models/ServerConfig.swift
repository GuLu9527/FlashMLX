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
        case embedding = "embedding"

        var displayName: String {
            switch self {
            case .lm: return String(localized: "Language Model")
            case .multimodal: return String(localized: "Multimodal")
            case .embedding: return String(localized: "Embedding")
            }
        }
    }

    var serverCommand: String {
        switch modelType {
        case .embedding:
            return "mlx_openai_server"
        case .lm, .multimodal:
            return "mlx_lm.server"
        }
    }

    var serverArguments: [String] {
        switch modelType {
        case .embedding:
            return [
                "launch",
                "--model-path", modelPath,
                "--model-type", "embeddings",
                "--port", String(port),
            ]
        case .lm, .multimodal:
            return [
                "--model", modelPath,
                "--port", String(port),
            ]
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
