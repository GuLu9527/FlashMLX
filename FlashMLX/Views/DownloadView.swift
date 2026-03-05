import SwiftUI

struct DownloadView: View {
    @EnvironmentObject var downloader: ModelDownloader
    @EnvironmentObject var scanner: ModelScanner
    @EnvironmentObject var configManager: ConfigManager
    @State private var searchText = ""
    @State private var showDeleteAlert = false
    @State private var modelToDelete: MLXModel?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search mlx-community models 搜索模型...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        downloader.fetchModels(query: searchText)
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        downloader.fetchModels()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                Button("Search 搜索") {
                    downloader.fetchModels(query: searchText)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content
            if downloader.isLoading {
                Spacer()
                ProgressView("Loading from HuggingFace 加载中...")
                    .font(.caption)
                Spacer()
            } else if let error = downloader.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry 重试") {
                        downloader.fetchModels(query: searchText)
                    }
                    .controlSize(.small)
                }
                Spacer()
            } else if downloader.remoteModels.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("Search or browse MLX models 搜索或浏览 MLX 模型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Browse Popular 浏览热门") {
                        downloader.fetchModels()
                    }
                    .controlSize(.small)
                }
                Spacer()
            } else {
                List {
                    // Local models section with delete
                    if !localModelsToShow.isEmpty {
                        Section("Installed Models 已安装") {
                            ForEach(localModelsToShow) { model in
                                LocalModelRow(model: model) {
                                    modelToDelete = model
                                    showDeleteAlert = true
                                }
                            }
                        }
                    }

                    // Remote models section
                    Section("Available 可用 (\(downloader.remoteModels.count))") {
                        ForEach(downloader.remoteModels) { model in
                            RemoteModelRow(
                                model: model,
                                status: downloader.downloadStatus[model.modelId] ?? .idle,
                                isInstalled: isModelInstalled(model),
                                onDownload: {
                                    downloader.download(
                                        model: model,
                                        pythonPath: configManager.config.pythonPath
                                    )
                                },
                                onCancel: {
                                    downloader.cancelDownload(modelId: model.modelId)
                                }
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            if downloader.remoteModels.isEmpty {
                downloader.fetchModels()
            }
        }
        .onChange(of: downloader.downloadStatus) { _, newStatus in
            if newStatus.values.contains(.completed) {
                scanner.scan()
            }
        }
        .alert("Delete Model 删除模型", isPresented: $showDeleteAlert, presenting: modelToDelete) { model in
            Button("Delete 删除", role: .destructive) {
                if downloader.deleteModel(model: model) {
                    scanner.scan()
                }
            }
            Button("Cancel 取消", role: .cancel) {}
        } message: { model in
            Text("Delete 删除 \"\(model.displayName)\"? This cannot be undone 此操作无法撤销。")
        }
    }

    private var localModelsToShow: [MLXModel] {
        if searchText.isEmpty {
            return scanner.models
        }
        return scanner.models.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func isModelInstalled(_ model: HFModel) -> Bool {
        let modelName = model.modelId
            .replacingOccurrences(of: "/", with: "--")
        return scanner.models.contains { $0.name == "models--\(modelName)" }
    }
}

struct RemoteModelRow: View {
    let model: HFModel
    let status: DownloadStatus
    let isInstalled: Bool
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Badge(text: "↓ \(model.downloadsDisplay)", color: .blue)
                    if let quant = model.quantizationTag {
                        Badge(text: quant, color: .purple)
                    }
                    if let size = model.estimatedSizeDisplay {
                        Badge(text: size, color: .orange)
                    }
                }
            }

            Spacer()

            if isInstalled {
                Label("Installed 已安装", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                switch status {
                case .idle:
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Download 下载")

                case .downloading(let progress):
                    HStack(spacing: 6) {
                        ProgressView(value: progress)
                            .frame(width: 60)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .frame(width: 30)
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }

                case .completed:
                    Label("Done 完成", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)

                case .error(let msg):
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption2)
                            .help(msg)
                        Button(action: onDownload) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct LocalModelRow: View {
    let model: MLXModel
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.caption)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Badge(text: model.sizeDisplay, color: .blue)
                    Badge(text: model.quantizationBadge, color: .purple)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Delete 删除")
        }
        .padding(.vertical, 2)
    }
}
