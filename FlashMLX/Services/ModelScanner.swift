import Foundation
import Combine

class ModelScanner: ObservableObject {
    @Published var models: [MLXModel] = []
    @Published var isScanning = false

    private let cacheDir: String

    init(cacheDir: String = "~/.cache/huggingface/hub") {
        self.cacheDir = (cacheDir as NSString).expandingTildeInPath
        scan()
    }

    func scan() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let found = self.scanModels()
            DispatchQueue.main.async {
                self.models = found
                self.isScanning = false
            }
        }
    }

    private func scanModels() -> [MLXModel] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cacheDir) else { return [] }
        guard let contents = try? fm.contentsOfDirectory(atPath: cacheDir) else { return [] }

        var results: [MLXModel] = []

        for dir in contents where dir.hasPrefix("models--") {
            let modelDir = (cacheDir as NSString).appendingPathComponent(dir)
            let snapshotsDir = (modelDir as NSString).appendingPathComponent("snapshots")

            guard fm.fileExists(atPath: snapshotsDir),
                  let snapshots = try? fm.contentsOfDirectory(atPath: snapshotsDir),
                  let latestSnapshot = snapshots.sorted().last else { continue }

            let snapshotPath = (snapshotsDir as NSString).appendingPathComponent(latestSnapshot)
            let configPath = (snapshotPath as NSString).appendingPathComponent("config.json")

            guard fm.fileExists(atPath: configPath),
                  let configData = fm.contents(atPath: configPath),
                  let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else { continue }

            guard isMLXModel(config: config, snapshotPath: snapshotPath) else { continue }

            let modelType = config["model_type"] as? String ?? "unknown"
            let quantization = getQuantization(config: config)
            let paramCount = getParameterCount(name: dir, config: config)
            let totalSize = directorySize(path: snapshotPath)
            let hasVision = config["vision_config"] is [String: Any]
                || config["visual"] is [String: Any]
                || config["image_size"] is Int
            let isEmbedding = self.isEmbeddingModel(name: dir, config: config, snapshotPath: snapshotPath)

            let model = MLXModel(
                id: dir,
                name: dir,
                path: snapshotPath,
                size: totalSize,
                modelType: modelType,
                quantization: quantization,
                parameterCount: paramCount,
                hasVisionConfig: hasVision,
                isEmbeddingModel: isEmbedding
            )
            results.append(model)
        }

        return results.sorted { $0.displayName < $1.displayName }
    }

    private func isMLXModel(config: [String: Any], snapshotPath: String) -> Bool {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: snapshotPath) else { return false }

        let hasMLXWeights = files.contains { $0 == "weights.npz" || $0.contains("mlx") }
        if hasMLXWeights { return true }

        let hasSafetensors = files.contains { $0.hasSuffix(".safetensors") }
        guard hasSafetensors else { return false }

        // MLX quantized models have quantization_config with bits field
        if let qc = config["quantization_config"] as? [String: Any], qc["bits"] is Int {
            return true
        }

        // Single safetensors file (typical MLX converted model) vs PyTorch shards
        let safetensorFiles = files.filter { $0.hasSuffix(".safetensors") }
        let hasSingleWeight = safetensorFiles.count == 1 && safetensorFiles.first == "model.safetensors"

        // Check for MLX-specific: single model.safetensors without pytorch_model.bin
        let hasPyTorch = files.contains { $0.contains("pytorch_model") || $0.contains(".bin") }
        if hasSingleWeight && !hasPyTorch && config["model_type"] != nil {
            return true
        }

        return false
    }

    private func getQuantization(config: [String: Any]) -> String? {
        guard let quantConfig = config["quantization_config"] as? [String: Any] else { return nil }
        if let bits = quantConfig["bits"] as? Int {
            return "\(bits)-bit"
        }
        if let quantType = quantConfig["quant_type"] as? String {
            return quantType
        }
        return nil
    }

    private func getParameterCount(name: String, config: [String: Any]) -> String? {
        // Try to extract from model name first (e.g. "Qwen3-8B-4bit" → "8B")
        let pattern = #"(\d+(?:\.\d+)?)[Bb](?:-|$|_)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name) {
            let value = String(name[range])
            return "\(value)B"
        }

        // Fallback: estimate from architecture
        guard let hiddenSize = config["hidden_size"] as? Int,
              let numLayers = config["num_hidden_layers"] as? Int,
              let vocabSize = config["vocab_size"] as? Int else { return nil }

        let intermediateSize = config["intermediate_size"] as? Int ?? hiddenSize * 4
        let attn = hiddenSize * hiddenSize * 4
        let ffn = hiddenSize * intermediateSize * 3
        let params = Double((attn + ffn) * numLayers + vocabSize * hiddenSize) / 1_000_000_000.0
        return String(format: "%.1fB", params)
    }

    private func isEmbeddingModel(name: String, config: [String: Any], snapshotPath: String) -> Bool {
        let embeddingModelTypes = [
            "bert", "nomic_bert", "xlm-roberta", "xlm_roberta",
            "roberta", "distilbert", "albert", "deberta",
        ]
        let typeLower = (config["model_type"] as? String ?? "").lowercased()
        if embeddingModelTypes.contains(where: { typeLower.contains($0) }) {
            return true
        }

        let embeddingNameKeywords = ["embed", "e5-", "bge-", "gte-", "jina-embed"]
        let nameLower = name.lowercased()
        if embeddingNameKeywords.contains(where: { nameLower.contains($0) }) {
            return true
        }

        let fm = FileManager.default
        let poolingDir = (snapshotPath as NSString).appendingPathComponent("1_Pooling")
        if fm.fileExists(atPath: poolingDir) {
            return true
        }

        return false
    }

    private func directorySize(path: String) -> Int64 {
        let fm = FileManager.default
        var totalSize: Int64 = 0
        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }

        while let file = enumerator.nextObject() as? String {
            let filePath = (path as NSString).appendingPathComponent(file)
            // Resolve symlinks (HuggingFace cache uses symlinks to blobs/)
            let resolvedPath: String
            if let dest = try? fm.destinationOfSymbolicLink(atPath: filePath) {
                if dest.hasPrefix("/") {
                    resolvedPath = dest
                } else {
                    resolvedPath = ((filePath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(dest)
                }
            } else {
                resolvedPath = filePath
            }
            if let attrs = try? fm.attributesOfItem(atPath: resolvedPath),
               let fileType = attrs[.type] as? FileAttributeType,
               fileType == .typeRegular,
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }
}
