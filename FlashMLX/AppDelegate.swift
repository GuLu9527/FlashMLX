import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var detachedWindow: NSWindow?
    private let scanner = ModelScanner()
    private let serverManager = ServerManager()
    private let configManager = ConfigManager()
    private let updateChecker = UpdateChecker()
    private lazy var hostingController: NSHostingController<some View> = {
        NSHostingController(
            rootView: PopoverView()
                .environmentObject(scanner)
                .environmentObject(serverManager)
                .environmentObject(configManager)
                .environmentObject(updateChecker)
        )
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 700, height: 480)
        popover.behavior = .transient
        popover.contentViewController = hostingController
        self.popover = popover

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "FlashMLX")
            button.action = #selector(togglePopover)
            button.target = self
        }

        serverManager.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.updateStatusIcon(status)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateStatusIcon(_ status: ServerStatus) {
        guard let button = statusItem?.button else { return }
        let symbolName: String
        let tintColor: NSColor

        switch status {
        case .running:
            symbolName = "bolt.fill"
            tintColor = .systemGreen
        case .starting:
            symbolName = "bolt.fill"
            tintColor = .systemOrange
        case .error:
            symbolName = "bolt.trianglebadge.exclamationmark"
            tintColor = .systemRed
        case .stopped:
            symbolName = "bolt.fill"
            tintColor = .secondaryLabelColor
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "FlashMLX")
        let config = NSImage.SymbolConfiguration(paletteColors: [tintColor])
        button.image = image?.withSymbolConfiguration(config)
    }

    @objc private func togglePopover() {
        // 已拆卸为窗口时，切换窗口显示
        if let window = detachedWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 默认 Popover 模式
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - 拆卸为独立窗口

    func detachToWindow() {
        popover?.performClose(nil)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FlashMLX"
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.delegate = self
        window.contentViewController = hostingController

        self.detachedWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === detachedWindow {
            detachedWindow = nil
        }
    }
}
