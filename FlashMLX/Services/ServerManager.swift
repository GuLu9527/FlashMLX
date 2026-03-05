import Foundation
import Combine
import UserNotifications

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running
    case error(String)

    var displayText: String {
        switch self {
        case .stopped: return String(localized: "Stopped")
        case .starting: return String(localized: "Starting...")
        case .running: return String(localized: "Running")
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

class ServerManager: NSObject, ObservableObject {
    @Published var status: ServerStatus = .stopped
    @Published var logs: [String] = []
    @Published var currentModel: String?
    @Published var startTime: Date?
    @Published var memoryUsageMB: Double = 0

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var memoryTimer: Timer?
    private var healthTimer: Timer?
    private var currentPort: Int = 8000
    @Published var isHealthy = false
    private var consecutiveFailures = 0
    private var statusCancellable: AnyCancellable?

    override init() {
        super.init()
        // Defer notification permission to after app finishes launching
        DispatchQueue.main.async { [weak self] in
            self?.requestNotificationPermission()
        }
        statusCancellable = $status
            .removeDuplicates()
            .sink { [weak self] newStatus in
                switch newStatus {
                case .running:
                    self?.sendNotification(title: "FlashMLX", body: String(localized: "Server started"))
                case .error(let msg):
                    self?.sendNotification(title: "FlashMLX", body: "Error: \(msg)")

                default:
                    break
                }
            }
    }

    var uptime: String {
        guard let start = startTime else { return "--" }
        let interval = Date().timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    func start(config: ServerConfig) {
        guard !status.isRunning, status != .starting else { return }

        status = .starting
        logs = []

        let pythonPath = (config.pythonPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: pythonPath) else {
            status = .error("Python not found at \(pythonPath)")
            appendLog("ERROR: Python not found at \(pythonPath)")
            appendLog("Please install: python3 -m venv ~/mlx-env && ~/mlx-env/bin/pip install mlx-lm")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [
            "-m", "mlx_lm.server",
            "--model", config.modelPath,
            "--port", String(config.port),
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        self.outputPipe = outPipe
        self.errorPipe = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(str)
                if self?.isServerReady(str) == true {
                    self?.status = .running
                    self?.startTime = Date()
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(str)
                if self?.isServerReady(str) == true {
                    self?.status = .running
                    self?.startTime = Date()
                }
            }
        }

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.memoryTimer?.invalidate()
                if process.terminationStatus != 0 && self?.status != .stopped {
                    self?.status = .error("Exit code: \(process.terminationStatus)")
                } else {
                    self?.status = .stopped
                }
                self?.startTime = nil
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.currentModel = config.modelPath
            appendLog("Starting server with model: \(config.modelPath)")
            appendLog("Port: \(config.port)")

            startMemoryMonitoring()
            startHealthCheck(port: config.port)
            currentPort = config.port

            // Fallback: mark as running after 8s if no explicit signal
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                if case .starting = self?.status {
                    self?.status = .running
                    self?.startTime = Date()
                }
            }
        } catch {
            status = .error(error.localizedDescription)
            appendLog("ERROR: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            status = .stopped
            return
        }

        memoryTimer?.invalidate()
        healthTimer?.invalidate()
        proc.terminate()

        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if proc.isRunning {
                proc.interrupt()
            }
        }

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        process = nil
        currentModel = nil
        startTime = nil
        isHealthy = false
        consecutiveFailures = 0
        status = .stopped
        appendLog("Server stopped.")
        sendNotification(title: "FlashMLX", body: String(localized: "Server stopped"))
    }

    private func isServerReady(_ output: String) -> Bool {
        let readySignals = [
            "Uvicorn running",
            "Started server",
            "Application startup complete",
            "INFO:     Started server process",
        ]
        return readySignals.contains { output.contains($0) }
    }

    private func appendLog(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logs.append(trimmed)
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }

    private func updateMemoryUsage() {
        guard let pid = process?.processIdentifier, process?.isRunning == true else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-o", "rss=", "-p", String(pid)]
            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let kb = Double(str) {
                    DispatchQueue.main.async {
                        self?.memoryUsageMB = kb / 1024.0
                    }
                }
            } catch {}
        }
    }

    // MARK: - Health Check

    private func startHealthCheck(port: Int) {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.pingServer(port: port)
        }
    }

    private func pingServer(port: Int) {
        guard status.isRunning else { return }
        guard let url = URL(string: "http://localhost:\(port)/v1/models") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self = self, self.status.isRunning else { return }
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.isHealthy = true
                    self.consecutiveFailures = 0
                } else {
                    self.consecutiveFailures += 1
                    if self.consecutiveFailures >= 3 {
                        self.isHealthy = false
                        self.appendLog("WARNING: Health check failed \(self.consecutiveFailures) times")
                        if self.consecutiveFailures == 3 {
                            self.sendNotification(
                                title: "FlashMLX",
                                body: String(localized: "Server not responding")
                            )
                        }
                    }
                }
            }
        }.resume()
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        guard let _ = Bundle.main.bundleIdentifier else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        guard let _ = Bundle.main.bundleIdentifier else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    deinit {
        stop()
    }
}
