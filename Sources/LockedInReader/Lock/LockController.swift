import AppKit
import IOKit.pwr_mgt

/// Borderless windows refuse key status by default; the reader and the
/// passphrase field both need it.
final class LockWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) {}   // swallow Esc
}

/// Applies and maintains the kiosk lockdown: full-screen cover windows on every
/// display, restricted presentation options, sleep prevention, and a watchdog
/// that pulls focus back if anything steals it.
@MainActor
final class LockController {
    private(set) var isLocked = false
    private(set) var mainWindow: LockWindow?

    private var coverWindows: [NSWindow] = []
    private var sleepAssertions: [IOPMAssertionID] = []
    private var watchdog: Timer?
    private var resignObserver: NSObjectProtocol?

    private static let lockedOptions: NSApplication.PresentationOptions = [
        .hideDock,
        .hideMenuBar,
        .disableProcessSwitching,     // Cmd+Tab
        .disableForceQuit,            // Cmd+Opt+Esc
        .disableHideApplication,      // Cmd+H
        .disableSessionTermination,   // logout / shutdown prompts
        .disableAppleMenu,
    ]

    /// Show `content` in a borderless window above everything and lock the Mac down.
    func engage(content: NSView) -> NSWindow {
        guard !isLocked else { return mainWindow! }
        isLocked = true

        let screens = NSScreen.screens
        let primary = screens.first ?? NSScreen.main!

        let window = LockWindow(contentRect: primary.frame, styleMask: [.borderless],
                                backing: .buffered, defer: false)
        window.level = .screenSaver
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = content
        window.setFrame(primary.frame, display: true)
        mainWindow = window

        // Black out secondary displays so they can't be used as an escape.
        for screen in screens.dropFirst() {
            let cover = LockWindow(contentRect: screen.frame, styleMask: [.borderless],
                                   backing: .buffered, defer: false)
            cover.level = .screenSaver
            cover.backgroundColor = .black
            cover.isOpaque = true
            cover.isReleasedWhenClosed = false
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            cover.setFrame(screen.frame, display: true)
            cover.orderFrontRegardless()
            coverWindows.append(cover)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.presentationOptions = Self.lockedOptions
        preventSleep()

        // Anything that steals focus gets it taken right back.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reassert() }
        }
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reassert() }
        }
        return window
    }

    /// Tear everything down and give the Mac back.
    func release() {
        guard isLocked else { return }
        isLocked = false
        watchdog?.invalidate()
        watchdog = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil

        NSApp.presentationOptions = []
        allowSleep()
        coverWindows.forEach { $0.close() }
        coverWindows = []
        mainWindow?.close()
        mainWindow = nil
    }

    private func reassert() {
        guard isLocked, let window = mainWindow else { return }
        if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
        if NSApp.presentationOptions != Self.lockedOptions {
            NSApp.presentationOptions = Self.lockedOptions
        }
        if !window.isKeyWindow { window.makeKeyAndOrderFront(nil) }
        // Re-cover if displays were attached/detached or the frame drifted.
        if let primary = NSScreen.screens.first, window.frame != primary.frame {
            window.setFrame(primary.frame, display: true)
        }
    }

    // MARK: Sleep prevention

    private func preventSleep() {
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep] {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Locked In Reader session" as CFString, &id)
            if result == kIOReturnSuccess { sleepAssertions.append(id) }
        }
    }

    private func allowSleep() {
        sleepAssertions.forEach { IOPMAssertionRelease($0) }
        sleepAssertions = []
    }
}
