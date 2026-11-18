import AppKit
import HocusFocusCore
import HocusFocusBrand
import SwiftUI

final class DashboardModel: ObservableObject {
    @Published var config = Configuration()
    @Published var enabled = true
    @Published var trusted = false
    @Published var configValid = true
    @Published var message: String?
    @Published var newApp = ""
    @Published var runningApps: [NSRunningApplication] = []
    var onSave: ((Configuration) -> Void)?
    var onToggle: ((Bool) -> Void)?
    var onReload: (() -> Void)?
    var onEdit: (() -> Void)?
    var onPermissions: (() -> Void)?
    var onQuit: (() -> Void)?
    func save() { onSave?(config) }
    func refreshApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != AppControl.bundleID }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    func addApp(_ identifier: String) {
        let value = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !config.apps.list.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        config.apps.list.append(value)
        save()
    }
}

struct DashboardView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var loginItem: LoginItemController
    private let accent = Color(nsColor: Brand.Palette.accent.nsColor)
    private let presetColor = Color(red: 139 / 255.0, green: 213 / 255.0, blue: 202 / 255.0)
    private let delayPresets = [(value: 150, name: "Quick"), (value: 400, name: "Balanced"),
                                (value: 750, name: "Relaxed")]

    var body: some View {
        VStack(spacing: 16) {
            header
            if !model.trusted { permissionNotice }
            VStack(spacing: 12) { focusControls; appControls }.disabled(!model.configValid)
            startupControls
            if let message = model.message {
                Text(message).font(.system(size: 11)).foregroundStyle(Color(nsColor: Brand.Palette.error.nsColor))
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            footer
        }
        .padding(20).frame(width: 400)
        .background(Color(nsColor: Brand.Palette.background.nsColor))
        .preferredColorScheme(.dark).tint(accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: BrandArtwork.mark(size: 38)).frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Brand.top).foregroundStyle(.white.opacity(0.45))
                    Text(Brand.bottom).foregroundStyle(accent)
                }.font(.system(size: 9, design: .monospaced)).fixedSize()
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("HocusFocus")
            HStack {
                Text("YOUR POINTER. YOUR PACE.")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(model.trusted && model.enabled ? accent : Color.secondary).frame(width: 5, height: 5)
                    Text(!model.trusted ? "SETUP" : model.enabled ? "LIVE" : "PAUSED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(.white.opacity(0.05), in: Capsule())
            }
        }
    }

    private var permissionNotice: some View {
        Button { model.onPermissions?() } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text("One permission, then you're in.").font(.system(size: 12, weight: .semibold))
                    Text("Request access and open Accessibility settings.").font(.system(size: 10))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(accent).padding(12)
            .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private var focusControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { model.enabled }, set: { model.onToggle?($0) })) {
                Label { Text("Focus follows mouse") } icon: { Image(nsImage: BrandArtwork.mark()).resizable().frame(width: 16, height: 16) }
                    .font(.system(size: 13, weight: .semibold))
            }.toggleStyle(.switch)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hover delay").font(.system(size: 12, weight: .medium))
                    Text("A little time to change your mind.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Delay", value: Binding(
                    get: { model.config.focus.delayMS }, set: { model.config.focus.delayMS = $0 }
                ), format: .number.grouping(.never))
                .font(.system(size: 21, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.trailing).textFieldStyle(.plain).frame(width: 72)
                .onSubmit { model.save() }.accessibilityLabel("Hover delay in milliseconds")
                Text("ms").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            delaySlider
            HStack(spacing: 7) {
                ForEach(delayPresets, id: \.value) { preset in
                    Button {
                        model.config.focus.delayMS = preset.value
                        model.save()
                    } label: {
                        VStack(spacing: 3) {
                            Text(preset.name).font(.system(size: 10, weight: .medium))
                            Text("\(preset.value) ms").font(.system(size: 9, design: .monospaced))
                        }
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(model.config.focus.delayMS == preset.value ? presetColor.opacity(0.15) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(model.config.focus.delayMS == preset.value ? presetColor : Color.secondary)
                    }.buttonStyle(.plain)
                }
            }
            CursorStylePicker(selection: Binding(
                get: { model.config.feedback.cursorStyle },
                set: { model.config.feedback.cursorStyle = $0; model.save() }
            ))
            smallToggle("Bring window forward", symbol: "square.3.layers.3d", value: Binding(
                get: { model.config.focus.raiseWindow },
                set: { model.config.focus.raiseWindow = $0; model.save() }
            ))
            Text("When off, focus changes without bringing the window above other windows.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            smallToggle("Focus Orca terminal panes", symbol: "rectangle.split.2x1", value: Binding(
                get: { model.config.focus.orcaTerminalPanes },
                set: { model.config.focus.orcaTerminalPanes = $0; model.save() }
            ))
        }
        .padding(16).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.06)))
    }

    private var delaySlider: some View {
        DelaySlider(value: Binding(
            get: { model.config.focus.delayMS },
            set: { model.config.focus.delayMS = $0 }
        ), presets: delayPresets.map(\.value), markerColor: NSColor(presetColor),
                    accentColor: NSColor(accent),
                    onCommit: { model.save() })
            .frame(height: 54)
    }

    private var appControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("APPLICATIONS").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.5)
                Spacer()
                Text("\(model.config.apps.list.count) in list").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Picker("App filter", selection: Binding(
                get: { model.config.apps.mode }, set: { model.config.apps.mode = $0; model.save() }
            )) {
                Text("Only these apps").tag(Configuration.Apps.Mode.only)
                Text("Except these apps").tag(Configuration.Apps.Mode.except)
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(model.config.apps.list, id: \.self) { app in
                        HStack(spacing: 9) {
                            applicationIcon(app)
                            Text(applicationName(app)).font(.system(size: 11, weight: .medium)).lineLimit(1).help(app)
                            Spacer()
                            Button {
                                model.config.apps.list.removeAll { $0 == app }
                                model.save()
                            } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.white.opacity(0.25)) }
                            .buttonStyle(.plain).accessibilityLabel("Remove \(applicationName(app))")
                        }.padding(.vertical, 4)
                    }
                    if model.config.apps.list.isEmpty {
                        Text(model.config.apps.mode == .only ? "Add an app to follow focus." : "All apps are allowed.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }.frame(height: max(28, min(CGFloat(model.config.apps.list.count) * 26, 104)))
            HStack(spacing: 8) {
                TextField("App name", text: $model.newApp).textFieldStyle(.plain).font(.system(size: 11))
                    .onSubmit { addTypedApp() }
                Button(action: addTypedApp) { Image(systemName: "plus") }
                    .buttonStyle(.plain).accessibilityLabel("Add application")
                Menu {
                    ForEach(model.runningApps, id: \.processIdentifier) { app in
                        if let id = app.bundleIdentifier { Button(app.localizedName ?? id) { model.addApp(id) } }
                    }
                } label: { Image(systemName: "chevron.down") }
                .menuStyle(.borderlessButton).frame(width: 20).help("Choose a running app")
            }.padding(9).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(16).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.06)))
    }

    private var startupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            smallToggle("Launch at login", symbol: "power.circle", value: Binding(
                get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }
            ))
            if loginItem.needsApproval {
                Button { loginItem.openSettings() } label: {
                    Label("Allow in Login Items settings", systemImage: "arrow.up.right")
                }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(accent)
            }
            if let error = loginItem.error {
                Text(error).font(.system(size: 10)).foregroundStyle(Color(nsColor: Brand.Palette.error.nsColor))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button { model.onEdit?() } label: { Label("TOML", systemImage: "curlybraces") }
            Button { model.onReload?() } label: { Image(systemName: "arrow.clockwise") }
                .help("Reload TOML configuration").accessibilityLabel("Reload configuration")
            Spacer()
            Button { model.onQuit?() } label: { Label("Quit", systemImage: "power") }
                .help("Quit HocusFocus").accessibilityLabel("Quit HocusFocus")
        }.font(.system(size: 11)).foregroundStyle(.secondary).buttonStyle(.plain)
    }

    private func smallToggle(_ title: String, symbol: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) { Label(title, systemImage: symbol).font(.system(size: 11)).foregroundStyle(.secondary) }
            .toggleStyle(.switch).controlSize(.mini)
    }
    private func addTypedApp() { model.addApp(model.newApp); model.newApp = "" }

    private func applicationURL(_ identifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            ?? model.runningApps.first(where: {
                $0.localizedName?.caseInsensitiveCompare(identifier) == .orderedSame
            })?.bundleURL
    }

    private func applicationName(_ identifier: String) -> String {
        guard let url = applicationURL(identifier) else { return identifier }
        return url.deletingPathExtension().lastPathComponent
    }

    @ViewBuilder private func applicationIcon(_ identifier: String) -> some View {
        if let url = applicationURL(identifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 18, height: 18)
        } else {
            Image(systemName: "macwindow").foregroundStyle(accent).frame(width: 18, height: 18)
        }
    }
}
