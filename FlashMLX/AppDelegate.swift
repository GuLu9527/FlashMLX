import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let scanner = ModelScanner()
    private let serverManager = ServerManager()
    private let configManager = ConfigManager()
    private let downloader = ModelDownloader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 680, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(scanner)
                .environmentObject(serverManager)
                .environmentObject(configManager)
                .environmentObject(downloader)
        )
        self.popover = popover

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
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
