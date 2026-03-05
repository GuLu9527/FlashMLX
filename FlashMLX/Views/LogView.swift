import SwiftUI

struct LogView: View {
    @EnvironmentObject var server: ServerManager
    @State private var autoScroll = true
    @State private var searchText = ""

    private var filteredLogs: [(Int, String)] {
        let snapshot = Array(server.logs.enumerated())
        if searchText.isEmpty { return snapshot }
        return snapshot.filter { $0.1.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Filter logs...", text: $searchText)
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
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))

                Text("\(filteredLogs.count)/\(server.logs.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Toggle("Auto", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Clear") {
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
                        ForEach(filteredLogs, id: \.0) { index, line in
                            logLine(line, highlight: searchText)
                                .id(index)
                        }
                    }
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: server.logs.count) {
                    if autoScroll && searchText.isEmpty, let last = server.logs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logLine(_ line: String, highlight: String) -> some View {
        Text(line)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(logColor(for: line))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
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
