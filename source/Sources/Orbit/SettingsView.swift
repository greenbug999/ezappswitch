import SwiftUI
import AppKit
import ServiceManagement
import OrbitCore

private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var input: InputController
    @State private var atLogin = SMAppService.mainApp.status == .enabled
    private var hold: Binding<Double> {
        Binding(get: { store.preferences.effectiveHoldDuration }, set: { store.preferences.holdDuration = ($0 * 10).rounded() / 10 })
    }
    private var scale: Binding<Double> {
        Binding(get: { store.preferences.effectiveDialScale }, set: { store.preferences.dialScale = ($0 * 100).rounded() / 100 })
    }
    private var durationLabel: String { String(format: "%.1f s", store.preferences.effectiveHoldDuration) }
    private var sizeLabel: String { "\(Int((store.preferences.effectiveDialScale * 100).rounded()))%" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid.fill").font(.system(size: 28)).foregroundStyle(.tint).frame(width: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ezappswitch").font(.system(size: 21, weight: .semibold))
                    Text("Your apps, one gesture away.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enable launcher", isOn: $store.enabled).toggleStyle(.switch)
            }.padding(.horizontal, 26).padding(.vertical, 18)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    DialPreview(store: store)
                        .frame(width: 268 * store.preferences.effectiveDialScale, height: 268 * store.preferences.effectiveDialScale)
                        .frame(width: 408, height: 414)
                    Text("\(sizeLabel) · Live preview").font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 6)
                    Text("Hold \(durationLabel), point to an app, then release")
                        .font(.system(size: 13, weight: .medium)).padding(.top, 20)
                    Text("Center, an empty slot, or Esc to cancel\nMove before the menu opens to drag as usual")
                        .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5).padding(.top, 8)
                    Spacer(minLength: 18)
                }.frame(width: 408).background(SidebarMaterial())
                Divider()
                Form {
                    Section {
                        HStack {
                            Text("Menu slots")
                            Spacer()
                            Picker("Menu slots", selection: Binding(get: { min(8, max(2, store.state.slotCount)) }, set: { store.state.slotCount = $0 })) {
                                ForEach(2...8, id: \.self) { Text("\($0) slots").tag($0) }
                            }.labelsHidden().frame(width: 94).accessibilityLabel("Menu slots")
                        }
                        VStack(spacing: 7) {
                            HStack {
                                Text("Hold duration")
                                Spacer()
                                Text(durationLabel).monospacedDigit().foregroundStyle(.secondary)
                                Stepper("Hold duration", value: hold, in: 0.3...5, step: 0.1).labelsHidden().fixedSize()
                            }
                            Slider(value: hold, in: 0.3...5).labelsHidden().frame(maxWidth: .infinity).accessibilityLabel("Hold duration")
                        }.padding(.vertical, 3)
                        VStack(spacing: 7) {
                            HStack {
                                Text("Menu size")
                                Spacer()
                                Text(sizeLabel).monospacedDigit().foregroundStyle(.secondary)
                                Stepper("Menu size", value: scale, in: 0.75...1.5, step: 0.05).labelsHidden().fixedSize()
                            }
                            Slider(value: scale, in: 0.75...1.5).labelsHidden().frame(maxWidth: .infinity).accessibilityLabel("Menu size")
                        }.padding(.vertical, 3)
                        HStack {
                            Text("Default: 1 s · 100%").font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            Button("Reset defaults") { store.preferences = LauncherPreferences() }.buttonStyle(.link)
                                .help("Reset only hold duration and menu size")
                        }
                    } header: { Text("Gesture & appearance") }
                    Section {
                        ForEach(0..<2, id: \.self) { index in pinRow(index) }
                    } header: { Text("Pinned apps") }
                    Section {
                        if store.slots.count == 2 {
                            Text("Only the two pinned slots are shown.").foregroundStyle(.secondary)
                        } else {
                            ForEach(2..<store.slots.count, id: \.self) { index in recentRow(index) }
                        }
                    } header: {
                        HStack {
                            Text("Recent apps · \(max(0, store.slots.count - 2)) slots")
                            Spacer()
                            Button("Clear") { store.state.recent = [] }.buttonStyle(.link).disabled(store.state.recent.isEmpty)
                        }
                    } footer: {
                        Text("Updated when you switch apps. Pinned apps are excluded.\nTracked only while ezappswitch is running. Stored locally.")
                    }
                }.formStyle(.grouped).font(.system(size: 12)).frame(maxWidth: .infinity)
            }.frame(maxHeight: .infinity)
            Divider()
            HStack(spacing: 10) {
                Image(systemName: input.listening ? (store.enabled ? "checkmark.circle.fill" : "pause.circle.fill") : "hand.raised.fill")
                    .foregroundStyle(input.listening ? (store.enabled ? Color.green : Color.secondary) : Color.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(input.listening ? (store.enabled ? "Ready. Hold the left mouse button to launch." : "Launcher paused") : (input.trusted ? "Global input monitoring is not running" : "Accessibility permission required"))
                        .font(.system(size: 12, weight: .medium))
                    if !input.listening {
                        Text(input.trusted ? "Restart ezappswitch, or add it again in Accessibility." : "Allow ezappswitch to recognize holds in other apps.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !input.listening {
                    Button("Open System Settings") { input.requestPermission() }.buttonStyle(.borderedProminent).controlSize(.small)
                }
            }.padding(.horizontal, 24).padding(.vertical, 13)
            HStack {
                Toggle("Launch at login", isOn: $atLogin).toggleStyle(.checkbox).onChange(of: atLogin) { value in
                    do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { store.error = "Could not change launch at login: \(error.localizedDescription)"; atLogin = SMAppService.mainApp.status == .enabled }
                }
                Spacer()
                Text("Pause anytime from the menu bar").foregroundStyle(.secondary)
                Button("Quit ezappswitch") { NSApp.terminate(nil) }.buttonStyle(.link)
            }.font(.system(size: 11)).padding(.horizontal, 24).padding(.bottom, 15)
        }
        .frame(width: 860, height: 744)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to complete action", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    private func pinRow(_ index: Int) -> some View {
        let app = store.slots[index]
        return HStack(spacing: 10) {
            if let app { Image(nsImage: store.icon(app)).resizable().frame(width: 28, height: 28) }
            else { Image(systemName: "plus.app").font(.system(size: 23)).foregroundStyle(.secondary).frame(width: 28, height: 28) }
            VStack(alignment: .leading, spacing: 3) {
                Text(app?.name ?? "Choose an app").font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text("Pinned \(index + 1)").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 3)
            if app != nil {
                Button { store.state.pin(nil, at: index) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear pinned slot \(index + 1)").help("Clear this pinned slot")
            }
            Button(app == nil ? "Choose…" : "Change…") { store.choosePin(index) }.controlSize(.small)
                .accessibilityLabel("Choose pinned app \(index + 1)")
        }.padding(.vertical, 4)
    }

    private func recentRow(_ index: Int) -> some View {
        HStack(spacing: 9) {
            if let app = store.slots[index] {
                Image(nsImage: store.icon(app)).resizable().frame(width: 22, height: 22)
                Text(app.name).lineLimit(1)
                Spacer()
            } else {
                Image(systemName: "circle.dashed").foregroundStyle(.secondary).frame(width: 22, height: 22)
                Text("Waiting for an app").foregroundStyle(.secondary)
                Spacer()
            }
            Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
        }.font(.system(size: 12)).frame(height: 23)
    }
}
