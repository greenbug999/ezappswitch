import AppKit
import ApplicationServices
import Combine
import OrbitCore

final class InputController: ObservableObject {
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var listening = false
    @Published var loginEnabled = false
    let store: AppStore
    let panel = DialPanel()
    weak var configurationWindow: NSWindow?
    private var gesture = Gesture()
    private var pendingDown: CGEvent?
    private var holdTimer: Timer?
    private var permissionTimer: Timer?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var origin = CGPoint.zero
    private var armed = false
    private var sleepingObserver: NSObjectProtocol?
    private let injectedMarker: Int64 = 0x4F52424954

    init(store: AppStore, monitor: Bool = true) {
        self.store = store
        guard monitor else { return }
        refreshPermission()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refreshPermission() }
        sleepingObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.cancelGesture() }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
        refreshPermission()
    }

    func refreshPermission() {
        let allowed = AXIsProcessTrusted()
        if trusted != allowed { trusted = allowed }
        if allowed && tap == nil { installTap() }
        if !allowed && tap != nil { stop() }
    }

    private func installTap() {
        let events: [CGEventType] = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .mouseMoved, .rightMouseDown, .otherMouseDown, .keyDown, .flagsChanged, .scrollWheel]
        let mask = events.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { proxy, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<InputController>.fromOpaque(context).takeUnretainedValue().handle(proxy: proxy, type: type, event: event)
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            listening = false; return
        }
        tap = created
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CGEvent.tapEnable(tap: created, enable: true)
        listening = true
    }

    func stop() {
        cancelGesture()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil; runLoopSource = nil; listening = false
    }

    private func cancelGesture() {
        holdTimer?.invalidate(); holdTimer = nil
        _ = gesture.cancel(); pendingDown = nil; panel.orderOut(nil)
    }

    private func replayDown(proxy: CGEventTapProxy) {
        pendingDown?.tapPostEvent(proxy)
        pendingDown = nil
    }

    private func cocoaPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancelGesture()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == injectedMarker { return Unmanaged.passUnretained(event) }
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .leftMouseDown:
            if let window = configurationWindow, window.isVisible, window.isKeyWindow,
               window.frame.contains(cocoaPoint(event.location)) { return pass }
            let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
            guard store.enabled, event.flags.intersection(modifiers).isEmpty, NSApp.modalWindow == nil else { return pass }
            origin = cocoaPoint(event.location); armed = false
            pendingDown = event.copy()
            let duration = store.preferences.effectiveHoldDuration
            _ = gesture.down(at: event.location, time: ProcessInfo.processInfo.systemUptime, holdDuration: duration)
            holdTimer?.invalidate()
            let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in self?.holdCompleted() }
            holdTimer = timer; RunLoop.main.add(timer, forMode: .common)
            return nil
        case .leftMouseDragged, .mouseMoved:
            let effect = gesture.move(to: event.location)
            if effect == .replayDownThenPass {
                holdTimer?.invalidate(); replayDown(proxy: proxy); return pass
            }
            if gesture.state == .choosing {
                let point = cocoaPoint(event.location)
                if hypot(point.x - origin.x, point.y - origin.y) >= 12 * panel.dialScale { armed = true }
                if armed { panel.update(at: point) }
            }
            return effect == .swallow ? nil : pass
        case .leftMouseUp:
            holdTimer?.invalidate(); holdTimer = nil
            let effect = gesture.up()
            if effect == .replayDownThenPass { replayDown(proxy: proxy); return pass }
            pendingDown = nil
            if effect == .select {
                if armed { panel.update(at: cocoaPoint(event.location)) }
                let app = armed ? panel.selectedApp : nil
                panel.orderOut(nil)
                if let app { DispatchQueue.main.async { [weak self] in self?.store.launch(app) } }
                return nil
            }
            return effect == .swallow ? nil : pass
        case .keyDown, .flagsChanged, .rightMouseDown, .otherMouseDown, .scrollWheel:
            let choosing = gesture.state == .choosing
            let effect = gesture.interrupt()
            if effect == .replayDownThenPass { holdTimer?.invalidate(); replayDown(proxy: proxy) }
            if effect == .cancel { panel.orderOut(nil); pendingDown = nil }
            if choosing && type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 53 { return nil }
            return pass
        default: return pass
        }
    }

    private func holdCompleted() {
        guard gesture.state == .pending else { return }
        if gesture.tick(time: ProcessInfo.processInfo.systemUptime, buttonDown: CGEventSource.buttonState(.hidSystemState, button: .left), enabled: store.enabled) == .show {
            pendingDown = nil
            panel.show(at: origin, slots: store.slots, scale: store.preferences.effectiveDialScale, icon: { [weak self] item in self?.store.icon(item) ?? NSImage() })
        }
    }
}
