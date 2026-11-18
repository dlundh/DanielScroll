import AppKit
import ServiceManagement

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let engine: ScrollEngine
    private let settings = Settings.shared
    var needsPermission = false { didSet { updateIcon() } }

    init(engine: ScrollEngine) {
        self.engine = engine
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
    }

    func updateIcon() {
        let symbol = needsPermission ? "exclamationmark.triangle" : "computermouse"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DanielScroll")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !settings.enabled
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "DanielScroll", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if needsPermission {
            menu.addItem(item("⚠︎ Grant Accessibility access…", action: #selector(openAccessibilitySettings)))
        }

        menu.addItem(item("Smooth scrolling", checked: settings.enabled, action: #selector(toggleEnabled)))
        menu.addItem(.separator())

        menu.addItem(submenu("Step size", options: [
            ("Short (60 px)", 60), ("Medium (100 px)", 100), ("Long (150 px)", 150), ("Very long (220 px)", 220),
        ], current: settings.stepSize, action: #selector(setStepSize(_:))))

        menu.addItem(submenu("Animation", options: [
            ("Snappy (200 ms)", 200), ("Balanced (360 ms)", 360), ("Smooth (500 ms)", 500), ("Floaty (700 ms)", 700),
        ], current: settings.animationTime, action: #selector(setAnimationTime(_:))))

        menu.addItem(item("Acceleration", checked: settings.accelerationEnabled, action: #selector(toggleAcceleration)))
        menu.addItem(item("Smooth horizontal scrolling", checked: settings.horizontalSmoothing, action: #selector(toggleHorizontal)))
        menu.addItem(item("Reverse wheel direction", checked: settings.reverseDirection, action: #selector(toggleReverse)))
        menu.addItem(.separator())

        if let app = NSWorkspace.shared.frontmostApplication,
           let bundleID = app.bundleIdentifier,
           bundleID != Bundle.main.bundleIdentifier {
            let name = app.localizedName ?? bundleID
            let excluded = settings.isExcluded(bundleID)
            menu.addItem(item("Disable in \(name)", checked: excluded, action: #selector(toggleExcluded(_:)), value: bundleID))
        }
        if !settings.excludedApps.isEmpty {
            let list = NSMenu()
            for id in settings.excludedApps.sorted() {
                list.addItem(item(displayName(for: id), checked: true, action: #selector(toggleExcluded(_:)), value: id))
            }
            let parent = NSMenuItem(title: "Disabled apps", action: nil, keyEquivalent: "")
            parent.submenu = list
            menu.addItem(parent)
        }
        menu.addItem(.separator())

        menu.addItem(item("Launch at login", checked: SMAppService.mainApp.status == .enabled, action: #selector(toggleLaunchAtLogin)))
        menu.addItem(item("Quit DanielScroll", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, checked: Bool = false, action: Selector?, value: Any? = nil, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        menuItem.state = checked ? .on : .off
        menuItem.representedObject = value
        return menuItem
    }

    private func submenu(_ title: String, options: [(String, Double)], current: Double, action: Selector) -> NSMenuItem {
        let sub = NSMenu()
        for (label, value) in options {
            sub.addItem(item(label, checked: value == current, action: action, value: value))
        }
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = sub
        return parent
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        updateIcon()
    }

    @objc private func setStepSize(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { settings.stepSize = value }
    }

    @objc private func setAnimationTime(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { settings.animationTime = value }
    }

    @objc private func toggleAcceleration() { settings.accelerationEnabled.toggle() }
    @objc private func toggleHorizontal() { settings.horizontalSmoothing.toggle() }
    @objc private func toggleReverse() { settings.reverseDirection.toggle() }

    @objc private func toggleExcluded(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { settings.toggleExcluded(id) }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        engine.stop()
        NSApp.terminate(nil)
    }
}
