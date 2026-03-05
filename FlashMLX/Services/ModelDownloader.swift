import Foundation
import Combine

enum DownloadStatus: Equatable {
    case idle
    case downloading(progress: Double)
    case completed
    case error(String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

class ModelDownloader: ObservableObject {
    @Published var remoteModels: [HFModel] = []
    @Published var isLoading = false
    @Published var searchQuery = ""
    @Published var downloadStatus: [String: DownloadStatus] = [:]
    @Published var errorMessage: String?

    private var downloadProcesses: [String: Process] = [:]
    private let apiBase = "https://huggingface.co/api/models"

    func fetchModels(query: String = "") {
        isLoading = true
        errorMessage = nil

        var components = URLComponents(string: apiBase)!
        var queryItems = [
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "50"),
        ]
        if query.isEmpty {
            queryItems.append(URLQueryItem(name: "author", value: "mlx-community"))
        } else {
            queryItems.append(URLQueryItem(name: "search", value: "mlx-community \(query)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }

                do {
                    let models = try JSONDecoder().decode([HFModel].self, from: data)
                    self?.remoteModels = models
                } catch {
                    self?.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func download(model: HFModel, pythonPath: String) {
        let modelId = model.modelId
        guard downloadStatus[modelId]?.isDownloading != true else { return }

        downloadStatus[modelId] = .downloading(progress: 0)

        let expandedPython = (pythonPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPython) else {
            downloadStatus[modelId] = .error("Python not found at \(expandedPython)")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: expandedPython)
            proc.arguments = ["-m", "huggingface_hub", "download", modelId]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            DispatchQueue.main.async {
                self?.downloadProcesses[modelId] = proc
            }

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }

                DispatchQueue.main.async {
                    // Parse progress from huggingface_hub output
                    if let progress = self?.parseProgress(str) {
                        self?.downloadStatus[modelId] = .downloading(progress: progress)
                    }
                }
            }

            proc.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    self?.downloadProcesses.removeValue(forKey: modelId)
                    pipe.fileHandleForReading.readabilityHandler = nil

                    if process.terminationStatus == 0 {
                        self?.downloadStatus[modelId] = .completed
                    } else {
                        self?.downloadStatus[modelId] = .error("Exit code: \(process.terminationStatus)")
                    }
                }
            }

            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async {
                    self?.downloadStatus[modelId] = .error(error.localizedDescription)
                    self?.downloadProcesses.removeValue(forKey: modelId)
                }
            }
        }
    }

    func cancelDownload(modelId: String) {
        if let proc = downloadProcesses[modelId], proc.isRunning {
            proc.terminate()
        }
        downloadProcesses.removeValue(forKey: modelId)
        downloadStatus[modelId] = .idle
    }

    func deleteModel(model: MLXModel) -> Bool {
        let fm = FileManager.default
        // The model path points to a snapshot directory
        // We need to go up to the models-- directory to delete the whole model
        let snapshotPath = model.path
        let snapshotsDir = (snapshotPath as NSString).deletingLastPathComponent
        let modelDir = (snapshotsDir as NSString).deletingLastPathComponent

        do {
            try fm.removeItem(atPath: modelDir)
            return true
        } catch {
            return false
        }
    }

    private func parseProgress(_ output: String) -> Double? {
        // huggingface_hub download shows progress like "Downloading: 45%|..." or percentage patterns
        // Look for percentage patterns
        let patterns = [
            #"(\d+)%\|"#,
            #"(\d+(?:\.\d+)?)%"#,
            #"Downloading.*?(\d+(?:\.\d+)?)%"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output),
               let value = Double(output[range]) {
                return min(value / 100.0, 1.0)
            }
        }

        return nil
    }
}
