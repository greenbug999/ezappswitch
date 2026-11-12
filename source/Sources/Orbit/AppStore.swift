import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OrbitCore

final class AppStore: ObservableObject {
    @Published var state: LauncherState { didSet { save() } }
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var error: String?
    @Published var preferences: LauncherPreferences {
        didSet { if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "preferences") } }
    }
    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?
    private var icons: [String: NSImage] = [:]
    var slots: [AppRecord?] { state.slots }

    init(defaults: UserDefaults = .standard, observe: Bool = true) {
        self.defaults = defaults
        preferences = defaults.data(forKey: "preferences").flatMap { try? JSONDecoder().decode(LauncherPreferences.self, from: $0) } ?? LauncherPreferences()
        state = defaults.data(forKey: "launcherState").flatMap { try? JSONDecoder().decode(LauncherState.self, from: $0) } ?? LauncherState()
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        if observe {
            observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.record(app)
            }
            if let current = NSWorkspace.shared.frontmostApplication { record(current) }
        }
    }

    deinit { if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }

    func record(_ running: NSRunningApplication) {
        guard running.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              running.activationPolicy == .regular,
              let url = running.bundleURL,
              let item = Self.record(url) else { return }
        _ = icon(item)
        state.activate(item)
    }

    static func record(_ url: URL) -> AppRecord? {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        guard canonical.pathExtension.lowercased() == "app", let bundle = Bundle(url: canonical),
              bundle.executableURL != nil else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? canonical.deletingPathExtension().lastPathComponent
        return AppRecord(id: bundle.bundleIdentifier ?? canonical.path, name: name, path: canonical.path)
    }

    func icon(_ app: AppRecord) -> NSImage {
        if let image = icons[app.path] { return image }
        let image = NSWorkspace.shared.icon(forFile: app.path)
        image.size = NSSize(width: 64, height: 64)
        icons[app.path] = image
        return image
    }

    func choosePin(_ index: Int) {
        let picker = NSOpenPanel()
        picker.title = "Choose pinned app \(index + 1)"
        picker.message = "Choose an application for pinned slot \(index + 1)."
        picker.prompt = "Pin app"
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.treatsFilePackagesAsDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        guard picker.runModal() == .OK, let url = picker.url else { return }
        guard let app = Self.record(url), app.id != Bundle.main.bundleIdentifier else {
            error = "Choose another valid macOS application."; return
        }
        _ = icon(app)
        state.pin(app, at: index)
    }

    func launch(_ item: AppRecord) {
        guard FileManager.default.fileExists(atPath: item.path) else {
            error = "Could not find “\(item.name)”. It may have moved or been uninstalled. Choose it again or clear recent apps."; return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: item.path), configuration: configuration) { [weak self] _, failure in
            if let failure { DispatchQueue.main.async { self?.error = "Could not open “\(item.name)”: \(failure.localizedDescription)" } }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "launcherState") }
    }
}
