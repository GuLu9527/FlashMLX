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

    var isMultimodal: Bool {
        let multimodalTypes = ["llava", "idefics", "qwen2_vl", "pixtral", "paligemma", "fuyu", "kosmos"]
        return multimodalTypes.contains { modelType.lowercased().contains($0) }
    }

    var detectedModelType: ServerConfig.ModelType {
        isMultimodal ? .multimodal : .lm
    }
}
