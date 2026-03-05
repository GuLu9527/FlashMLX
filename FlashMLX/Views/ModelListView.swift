import SwiftUI

struct ModelListView: View {
    @EnvironmentObject var scanner: ModelScanner
    @Binding var selectedModel: MLXModel?
    @State private var searchText = ""

    private var filteredModels: [MLXModel] {
        if searchText.isEmpty {
            return scanner.models
        }
        return scanner.models.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("模型")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(filteredModels.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                Button(action: { scanner.scan() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(scanner.isScanning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Divider()

            if scanner.isScanning {
                Spacer()
                ProgressView("扫描中...")
                    .font(.caption)
                Spacer()
            } else if scanner.models.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("未找到 MLX 模型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("~/.cache/huggingface/hub/")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else if filteredModels.isEmpty {
                Spacer()
                Text("无匹配结果")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(selection: $selectedModel) {
                    ForEach(filteredModels) { model in
                        ModelRow(model: model)
                            .tag(model)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ModelRow: View {
    let model: MLXModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.displayName)
                .font(.caption)
                .lineLimit(2)

            HStack(spacing: 4) {
                Badge(text: model.sizeDisplay, color: .blue)
                Badge(text: model.quantizationBadge, color: .purple)
                if let params = model.parameterCount {
                    Badge(text: params, color: .orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(3)
    }
}
