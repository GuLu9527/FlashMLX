import Foundation

struct HFModel: Identifiable, Codable, Hashable {
    let id: String
    let modelId: String
    let downloads: Int
    let lastModified: String?
    let tags: [String]?
    let siblings: [HFSibling]?

    enum CodingKeys: String, CodingKey {
        case id
        case modelId
        case downloads
        case lastModified
        case tags
        case siblings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.modelId = try container.decode(String.self, forKey: .modelId)
        self.id = self.modelId
        self.downloads = try container.decodeIfPresent(Int.self, forKey: .downloads) ?? 0
        self.lastModified = try container.decodeIfPresent(String.self, forKey: .lastModified)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.siblings = try container.decodeIfPresent([HFSibling].self, forKey: .siblings)
    }

    var displayName: String {
        modelId.replacingOccurrences(of: "mlx-community/", with: "")
    }

    var downloadsDisplay: String {
        if downloads >= 1_000_000 {
            return String(format: "%.1fM", Double(downloads) / 1_000_000)
        } else if downloads >= 1_000 {
            return String(format: "%.1fK", Double(downloads) / 1_000)
        }
        return "\(downloads)"
    }

    var quantizationTag: String? {
        let name = displayName.lowercased()
        if name.contains("4bit") || name.contains("4-bit") { return "4-bit" }
        if name.contains("8bit") || name.contains("8-bit") { return "8-bit" }
        if name.contains("3bit") || name.contains("3-bit") { return "3-bit" }
        if name.contains("bf16") { return "bf16" }
        if name.contains("fp16") { return "fp16" }
        return nil
    }

    var estimatedSizeDisplay: String? {
        guard let siblings = siblings else { return nil }
        let totalBytes = siblings.reduce(0) { $0 + ($1.size ?? 0) }
        guard totalBytes > 0 else { return nil }
        let gb = Double(totalBytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(totalBytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

struct HFSibling: Codable, Hashable {
    let rfilename: String
    let size: Int64?
}
