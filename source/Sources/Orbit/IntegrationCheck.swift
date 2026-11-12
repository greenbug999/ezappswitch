#if DEBUG
import AppKit
import OrbitCore

private final class ClickProbe: NSView {
    var downs = 0, ups = 0, drags = 0
    override func mouseDown(with event: NSEvent) { downs += 1 }
    override func mouseUp(with event: NSEvent) { ups += 1 }
    override func mouseDragged(with event: NSEvent) { drags += 1 }
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: .systemTeal, ending: .systemIndigo)?.draw(in: bounds, angle: 25)
        for index in 0..<8 {
            NSColor.white.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: CGRect(x: 24 + index * 80, y: 80, width: 32, height: 310), xRadius: 12, yRadius: 12).fill()
        }
        ("ezappswitch · automated gesture check" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
    }
}

final class IntegrationCheck {
    private let defaults = UserDefaults(suiteName: "local.qinghuan.inputcheck")!
    private var store: AppStore!
    private var input: InputController!
    private var window: NSWindow!
    private let probe = ClickProbe()
    private var failures = 0
    private let originalPoint = CGEvent(source: nil)?.location
    private let originalApp = NSWorkspace.shared.frontmostApplication
    private var point = CGPoint.zero
    private let source = CGEventSource(stateID: .hidSystemState)

    func start() {
        defaults.removePersistentDomain(forName: "local.qinghuan.inputcheck")
        store = AppStore(defaults: defaults)
        input = InputController(store: store)
        guard input.listening else { failures += 1; print("INPUT CHECK BLOCKED: Accessibility required"); finish(); return }
        guard let calculator = AppStore.record(URL(fileURLWithPath: "/System/Applications/Calculator.app")) else { failures += 1; print("INPUT CHECK BLOCKED: Calculator missing"); finish(); return }
        store.state.pin(calculator, at: 0)
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 620, height: 470), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "ezappswitch input check"; window.contentView = probe; window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        point = CGPoint(x: window.frame.midX, y: window.frame.midY)
        Task { @MainActor in
            await pause(0.4)
            input.configurationWindow = window
            post(.leftMouseDown, at: point); await pause(0.08)
            check(probe.downs == 1, "settings mouse-down is delivered immediately for native controls")
            await pause(1.1)
            check(!input.panel.isVisible, "holding native settings controls does not open dial")
            post(.leftMouseUp, at: point); await pause(0.1)
            input.configurationWindow = nil; probe.downs = 0; probe.ups = 0; probe.drags = 0
            post(.leftMouseDown, at: point); await pause(0.08); post(.leftMouseUp, at: point); await pause(0.2)
            check(probe.downs == 1 && probe.ups == 1, "ordinary click delivers one down/up")
            post(.leftMouseDown, at: point); await pause(0.05)
            post(.leftMouseDragged, at: CGPoint(x: point.x + 35, y: point.y)); await pause(0.05)
            post(.leftMouseUp, at: CGPoint(x: point.x + 35, y: point.y)); await pause(1.1)
            check(probe.downs == 2 && probe.ups == 2 && probe.drags > 0 && !input.panel.isVisible, "drag is preserved and cancels hold")
            post(.leftMouseDown, at: point); await pause(1.15)
            check(input.panel.isVisible, "one-second hold opens real panel")
            if let directory = ProcessInfo.processInfo.environment["ORBIT_QA_CAPTURE_DIR"] {
                let capture = Process(); capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-l", "\(input.panel.windowNumber)", "\(directory)/native-glass.png"]
                do { try capture.run(); capture.waitUntilExit(); print("Native material capture: \(capture.terminationStatus)") }
                catch { print("Native material capture unavailable: \(error)") }
                let frame = input.panel.frame
                let y = (NSScreen.screens.first?.frame.maxY ?? 0) - frame.maxY
                let composite = Process(); composite.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                composite.arguments = ["-x", "-R", "\(Int(frame.minX)),\(Int(y)),\(Int(frame.width)),\(Int(frame.height))", "\(directory)/native-glass-composited.png"]
                do { try composite.run(); composite.waitUntilExit(); print("Composited material capture: \(composite.terminationStatus)") }
                catch { print("Composited material capture unavailable: \(error)") }
            }
            post(.leftMouseUp, at: point); await pause(0.15)
            check(!input.panel.isVisible && probe.downs == 2 && probe.ups == 2, "center release cancels and consumes click")
            post(.leftMouseDown, at: point); await pause(1.15)
            let escape = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: true)!
            escape.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: false)!.post(tap: .cghidEventTap)
            await pause(0.1); post(.leftMouseUp, at: point); await pause(0.15)
            check(!input.panel.isVisible && probe.downs == 2 && probe.ups == 2, "Escape cancels and consumes release")
            store.preferences.holdDuration = 0.5
            store.preferences.dialScale = 0.75
            let reloaded = AppStore(defaults: defaults, observe: false)
            check(reloaded.preferences.holdDuration == 0.5 && reloaded.preferences.dialScale == 0.75, "custom duration and size persist")
            post(.leftMouseDown, at: point); await pause(0.65)
            check(input.panel.isVisible && input.panel.frame.width == 303, "0.5-second hold opens 75-percent dial")
            var target = CGPoint(x: input.panel.centerPoint.x, y: input.panel.centerPoint.y + 123 * 0.75)
            post(.leftMouseDragged, at: target); await pause(0.1)
            check(input.panel.selectedApp?.id == calculator.id, "small dial hit region follows resized icon")
            post(.leftMouseDragged, at: CGPoint(x: input.panel.centerPoint.x, y: input.panel.centerPoint.y + 185 * 0.75)); await pause(0.1)
            check(input.panel.selectedApp == nil, "outside resized circle cancels selection")
            post(.leftMouseUp, at: point); await pause(0.1)
            store.preferences.holdDuration = 1.5
            store.preferences.dialScale = 1.5
            post(.leftMouseDown, at: point); await pause(1.1)
            check(!input.panel.isVisible, "1.5-second hold does not open at one second")
            await pause(0.55)
            check(input.panel.isVisible && input.panel.frame.width == 606, "custom long hold opens 150-percent dial")
            post(.leftMouseUp, at: point); await pause(0.1)
            store.preferences = LauncherPreferences()
            post(.leftMouseDown, at: point); await pause(1.15)
            target = CGPoint(x: input.panel.centerPoint.x, y: input.panel.centerPoint.y + 123)
            post(.leftMouseDragged, at: target); await pause(0.1)
            check(input.panel.selectedApp?.id == calculator.id, "hover selects pinned Calculator")
            post(.leftMouseUp, at: target); await pause(1.5)
            check(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == calculator.id, "release actually opens Calculator")
            check(store.state.recent.first?.id == calculator.id, "foreground notification updates recent apps")
            finish()
        }
    }

    private func pause(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
    private func post(_ type: CGEventType, at cocoa: CGPoint) {
        let quartz = CGPoint(x: cocoa.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - cocoa.y)
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: quartz, mouseButton: .left)!
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
    }
    private func check(_ condition: Bool, _ name: String) {
        if !condition { failures += 1 }
        print("\(condition ? "PASS" : "FAIL"): \(name)")
    }
    private func finish() {
        input?.stop(); window?.orderOut(nil)
        if let originalPoint { CGWarpMouseCursorPosition(originalPoint) }
        originalApp?.activate(options: [.activateIgnoringOtherApps])
        defaults.removePersistentDomain(forName: "local.qinghuan.inputcheck")
        print("INPUT CHECK: \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
#endif
