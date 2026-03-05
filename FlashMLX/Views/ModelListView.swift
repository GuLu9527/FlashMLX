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
        List(selection: $selectedModel) {
            if scanner.isScanning {
                HStack {
                    Spacer()
                    ProgressView("Scanning...")
                        .font(.caption)
                    Spacer()
                }
            } else if filteredModels.isEmpty && !scanner.models.isEmpty {
                Text("No matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredModels) { model in
                    ModelRow(model: model)
                        .tag(model)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search models...")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 4) {
                    Text("\(filteredModels.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button(action: { scanner.scan() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(scanner.isScanning)
                }
            }
        }
        .overlay {
            if scanner.models.isEmpty && !scanner.isScanning {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No MLX models found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("~/.cache/huggingface/hub/")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: MLXModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.displayName)
                .font(.system(.caption, weight: .medium))
                .lineLimit(1)

            HStack(spacing: 4) {
                Badge(text: model.sizeDisplay, color: .secondary)
                Badge(text: model.quantizationBadge, color: .secondary)
                if let params = model.parameterCount {
                    Badge(text: params, color: .secondary)
                }
                if model.isEmbeddingModel {
                    Badge(text: "Embed", color: .purple)
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
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(3)
    }
}
