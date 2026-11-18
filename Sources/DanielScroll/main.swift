import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = ScrollEngine()
    private var menuBar: MenuBarController!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(engine: engine)
        warnIfSmoothScrollIsRunning()
        startWhenTrusted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    /// The event tap needs Accessibility access. Prompt once, then poll until granted.
    private func startWhenTrusted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), engine.start() {
            menuBar.needsPermission = false
            return
        }
        menuBar.needsPermission = true
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            if AXIsProcessTrusted(), self.engine.start() {
                timer.invalidate()
                self.permissionTimer = nil
                self.menuBar.needsPermission = false
            }
        }
    }

    /// Two smoothing apps at once double-animate every notch.
    private func warnIfSmoothScrollIsRunning() {
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName == "SmoothScroll" && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        guard !others.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "SmoothScroll is also running"
        alert.informativeText = "Running both will double-smooth every scroll. Quit SmoothScroll?"
        alert.addButton(withTitle: "Quit SmoothScroll")
        alert.addButton(withTitle: "Keep Both")
        if alert.runModal() == .alertFirstButtonReturn {
            others.forEach { $0.terminate() }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
