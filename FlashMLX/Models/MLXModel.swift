import Foundation

struct MLXModel: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let modelType: String
    let quantization: String?
    let parameterCount: String?

    var displayName: String {
        name.replacingOccurrences(of: "models--", with: "")
            .replacingOccurrences(of: "--", with: "/")
    }

    var sizeDisplay: String {
        let gb = Double(size) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(size) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }

    var quantizationBadge: String {
        quantization ?? "fp16"
    }

    let hasVisionConfig: Bool

    let isEmbeddingModel: Bool

    var isMultimodal: Bool {
        if hasVisionConfig { return true }
        let multimodalTypes = [
            "llava", "idefics", "qwen2_vl", "qwen2_5_vl", "qwen_vl",
            "pixtral", "paligemma", "fuyu", "kosmos", "phi3_v", "phi3_vision",
            "mllama", "molmo", "internvl", "minicpm_v", "cogvlm",
            "blip", "git", "clip", "siglip", "florence",
        ]
        let nameLower = displayName.lowercased()
        let typeLower = modelType.lowercased()
        return multimodalTypes.contains { typeLower.contains($0) || nameLower.contains($0) }
    }

    var detectedModelType: ServerConfig.ModelType {
        if isEmbeddingModel { return .embedding }
        if isMultimodal { return .multimodal }
        return .lm
    }
}
