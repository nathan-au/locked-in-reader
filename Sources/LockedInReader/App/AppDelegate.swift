import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let lock = LockController()
    private var normalWindow: NSWindow?
    private var keyMonitor: Any?
    private var phaseSub: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        installEmergencyShortcut()

        phaseSub = model.$phase.removeDuplicates().sink { [weak self] phase in
            // @Published fires before the value changes; hop a tick so reads are consistent.
            DispatchQueue.main.async { self?.show(phase) }
        }

        model.restoreIfNeeded()
        if model.phase == .setup { show(.setup) }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Cmd+Q must not end a locked session.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.phase == .reading ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Phases

    private func show(_ phase: AppModel.Phase) {
        switch phase {
        case .setup:
            lock.release()
            presentNormalWindow(SetupView(model: model), title: "Locked In Reader")
        case .reading:
            normalWindow?.close()
            normalWindow = nil
            let host = NSHostingView(rootView: ReaderView(model: model))
            _ = lock.engage(content: host)
        case .done:
            lock.release()
            presentNormalWindow(DoneView(model: model), title: "Locked In Reader")
        }
    }

    private func presentNormalWindow<V: View>(_ view: V, title: String) {
        normalWindow?.close()
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        normalWindow = window
    }

    // MARK: Emergency shortcut (⌃⌥⌘U)

    private func installEmergencyShortcut() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.phase == .reading else { return event }
            let wanted: NSEvent.ModifierFlags = [.control, .option, .command]
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isSuperset(of: wanted), event.charactersIgnoringModifiers?.lowercased() == "u" {
                self.model.showUnlockPrompt.toggle()
                return nil
            }
            // Cmd+W / Cmd+M / Cmd+Q etc. are dead while locked.
            if flags.contains(.command), !self.model.showUnlockPrompt {
                let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if ["w", "m", "q", "h", "`"].contains(key) { return nil }
            }
            return event
        }
    }

    // MARK: Menu (needed for Cmd+C/V in text fields and Cmd+Q outside a session)

    private func installMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Locked In Reader", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }
}
