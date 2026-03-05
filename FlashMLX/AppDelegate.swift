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

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FlashMLX"
        window.minSize = NSSize(width: 580, height: 380)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(scanner)
                .environmentObject(serverManager)
                .environmentObject(configManager)
        )
        self.detachedWindow = window

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "FlashMLX")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Update menubar icon based on server status
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
        guard let window = detachedWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
