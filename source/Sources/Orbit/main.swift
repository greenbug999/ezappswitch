import AppKit
import SwiftUI
import Combine
import OrbitCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var store: AppStore!
    var input: InputController!
    var statusItem: NSStatusItem!
    var settings: NSWindow!
    var errorObserver: AnyCancellable?
    #if DEBUG
    var integration: IntegrationCheck?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if CommandLine.arguments.contains("--gesture-check") {
            integration = IntegrationCheck(); integration?.start(); return
        }
        #endif
        if CommandLine.arguments.contains("--diagnose") {
            let store = AppStore(observe: false)
            let input = InputController(store: store)
            print("Accessibility trusted: \(input.trusted); global event tap installed: \(input.listening)")
            input.stop(); NSApp.terminate(nil); return
        }
        if let position = CommandLine.arguments.firstIndex(of: "--render-check"), CommandLine.arguments.count > position + 1 {
            runRenderCheck(directory: CommandLine.arguments[position + 1]); return
        }
        store = AppStore()
        input = InputController(store: store)
        let menu = NSMenu(); menu.delegate = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "ezappswitch")
        statusItem.button?.toolTip = "ezappswitch · hold the left mouse button to launch"
        statusItem.menu = menu
        settings = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 860, height: 744), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        settings.title = "ezappswitch Settings"; settings.isReleasedWhenClosed = false
        input.configurationWindow = settings
        settings.contentView = NSHostingView(rootView: SettingsView(store: store, input: input))
        settings.center()
        errorObserver = store.$error.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] error in
            if error != nil { self?.showSettings() }
        }
        if !input.trusted || !UserDefaults.standard.bool(forKey: "hasOpened") || CommandLine.arguments.contains("--settings") { showSettings() }
        UserDefaults.standard.set(true, forKey: "hasOpened")
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.input.refreshPermission() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: input.listening ? (store.enabled ? "ezappswitch · Enabled" : "ezappswitch · Paused") : "ezappswitch · Permission needed", action: nil, keyEquivalent: "")
        menu.addItem(title); menu.addItem(.separator())
        add(menu, "Settings…", #selector(showSettings), ",")
        add(menu, store.enabled ? "Pause launcher" : "Enable launcher", #selector(toggleEnabled))
        menu.addItem(.separator())
        add(menu, "Quit ezappswitch", #selector(quit), "q")
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc func showSettings() { settings.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func toggleEnabled() { store.enabled.toggle() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) { input?.stop() }

    private func runRenderCheck(directory: String) {
        let dir = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "local.qinghuan.rendercheck")!
        defaults.removePersistentDomain(forName: "local.qinghuan.rendercheck")
        store = AppStore(defaults: defaults, observe: false)
        input = InputController(store: store, monitor: false)
        let paths = ["/System/Library/CoreServices/Finder.app", "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app", "/System/Applications/Notes.app", "/System/Applications/Calendar.app", "/System/Applications/Utilities/Terminal.app", "/System/Applications/System Settings.app"]
        let items = paths.compactMap { AppStore.record(URL(fileURLWithPath: $0)) }
        for app in items.reversed() { store.state.activate(app) }
        if let first = items.first { store.state.pin(first, at: 0) }
        if items.count > 1 { store.state.pin(items[1], at: 1) }
        for count in [2, 6, 8] {
            store.state.slotCount = count
            let dial = RadialView(frame: CGRect(x: 0, y: 0, width: 404, height: 404))
            dial.slots = store.slots; dial.icon = { [unowned self] in self.store.icon($0) }; dial.selection = count == 6 ? 2 : nil
            savePNG(dial, to: dir.appendingPathComponent("dial-\(count).png"))
        }
        store.state.slotCount = 6
        let view = NSHostingView(rootView: SettingsView(store: store, input: input))
        view.frame = CGRect(x: 0, y: 0, width: 860, height: 744)
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view; window.orderFrontRegardless(); view.layoutSubtreeIfNeeded()
        savePNG(view, to: dir.appendingPathComponent("settings.png"))
        store.state.slotCount = 8
        let eightView = NSHostingView(rootView: SettingsView(store: store, input: input))
        eightView.frame = view.frame; window.contentView = eightView; eightView.layoutSubtreeIfNeeded()
        savePNG(eightView, to: dir.appendingPathComponent("settings-8.png"))
        window.appearance = NSAppearance(named: .darkAqua)
        eightView.appearance = window.appearance
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        savePNG(eightView, to: dir.appendingPathComponent("settings-dark.png"))
        for scale in [0.75, 1.0, 1.5] {
            for theme in [NSAppearance.Name.aqua, .darkAqua] {
                let side = 404 * scale
                let dial = RadialView(frame: CGRect(x: 0, y: 0, width: side, height: side))
                dial.appearance = NSAppearance(named: theme)
                dial.slots = store.slots; dial.icon = { [unowned self] in self.store.icon($0) }
                dial.selection = 2
                savePNG(dial, to: dir.appendingPathComponent("dial-\(Int(scale * 100))-\(theme == .aqua ? "light" : "dark").png"))
            }
        }
        defaults.removePersistentDomain(forName: "local.qinghuan.rendercheck")
        print("Render check: \(items.count) real app records; 2/6/8-slot PNGs and settings PNG written.")
        NSApp.terminate(nil)
    }
    private func savePNG(_ view: NSView, to url: URL) {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: url) }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
