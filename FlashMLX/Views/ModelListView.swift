import SwiftUI

struct ModelListView: View {
    @EnvironmentObject var scanner: ModelScanner
    @Binding var selectedModel: MLXModel?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Models")
                    .font(.subheadline.bold())
                Spacer()
                Button(action: { scanner.scan() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(scanner.isScanning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if scanner.isScanning {
                Spacer()
                ProgressView("Scanning...")
                    .font(.caption)
                Spacer()
            } else if scanner.models.isEmpty {
                Spacer()
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
                Spacer()
            } else {
                List(selection: $selectedModel) {
                    ForEach(scanner.models) { model in
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
