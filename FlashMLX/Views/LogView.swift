import SwiftUI

struct LogView: View {
    @EnvironmentObject var server: ServerManager
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(server.logs.count) 行")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("自动滚动", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("清除") {
                    server.logs.removeAll()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(server.logs.indices, id: \.self) { index in
                            Text(server.logs[index])
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(logColor(for: server.logs[index]))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: server.logs.count) {
                    if autoScroll, let last = server.logs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logColor(for line: String) -> Color {
        if line.contains("ERROR") || line.contains("Error") {
            return .red
        } else if line.contains("WARNING") || line.contains("Warning") {
            return .orange
        } else if line.contains("Starting") || line.contains("running") {
            return .green
        }
        return .primary
    }
}
