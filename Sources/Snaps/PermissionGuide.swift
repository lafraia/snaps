import AppKit
import Combine
import SwiftUI

/// Walks the user through granting Screen Recording: opens the right System Settings pane and docks a
/// glass card to its window with a draggable Snaps icon to drop into the permission list.
@MainActor
final class PermissionGuide {
    static let shared = PermissionGuide()

    private static let settingsBundleID = "com.apple.systempreferences"
    private static let panelSize = NSSize(width: 460, height: 104)

    private let model = PermissionGuideModel()
    private var panel: GlassPanel?
    private var timer: Timer?
    private var missingTicks = 0

    var isActive: Bool { timer != nil }

    func start() {
        // Already allowed and active in this process: nothing to do.
        guard !CGPreflightScreenCaptureAccess() else { return }

        model.stage = ScreenPermission.isGrantedLive ? .granted : .drag
        ScreenPermission.openSystemSettings()

        if panel == nil {
            let panel = GlassPanel(contentSize: Self.panelSize)
            panel.onCancel = { [weak self] in self?.stop() }
            panel.setContent(
                PermissionGuideView(
                    model: model,
                    onDropped: { [weak self] in self?.model.stage = .enable },
                    onRelaunch: { ScreenPermission.relaunch() },
                    onClose: { [weak self] in self?.stop() }
                ),
                cornerRadius: 26
            )
            panel.alphaValue = 0
            self.panel = panel
        }

        missingTicks = 0
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.close()
            }
        })
    }

    private func tick() {
        guard let panel else { return }

        if model.stage != .granted, ScreenPermission.isGrantedLive {
            withAnimation(.snappy) { model.stage = .granted }
            AppState.shared.refreshPermission()
        }

        // Follow the System Settings window; give it a moment to open, and stop if it's closed.
        guard let window = Self.systemSettingsWindowFrame() else {
            missingTicks += 1
            panel.orderOut(nil)
            if missingTicks > 40 { stop() }
            return
        }
        missingTicks = 0

        let frontmost = NSWorkspace.shared.frontmostApplication
        let relevant = frontmost?.bundleIdentifier == Self.settingsBundleID
            || frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || NSEvent.pressedMouseButtons != 0 // mid-drag
        guard relevant else {
            panel.orderOut(nil)
            return
        }

        let frame = dockedFrame(below: window)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 1
            }
            panel.invalidateShadow()
        }
    }

    /// Centers the card under the System Settings window, or tucks it inside the bottom edge if there's no room.
    private func dockedFrame(below window: NSRect) -> NSRect {
        let size = Self.panelSize
        let screen = NSScreen.screens.first { $0.frame.intersects(window) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? window
        let x = min(max(window.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        var y = window.minY - size.height - 14
        if y < visible.minY + 8 {
            y = window.minY + 16
        }
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// The main System Settings window in Cocoa (bottom-left origin) coordinates.
    private static func systemSettingsWindowFrame() -> NSRect? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundleID).first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height
        else { return nil }

        let frames = windows.compactMap { info -> CGRect? in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width > 200, rect.height > 200
            else { return nil }
            return rect
        }
        guard let rect = frames.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}

@MainActor
final class PermissionGuideModel: ObservableObject {
    enum Stage { case drag, enable, granted }
    @Published var stage: Stage = .drag
}

struct PermissionGuideView: View {
    @ObservedObject var model: PermissionGuideModel
    let onDropped: () -> Void
    let onRelaunch: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(8)
            .help("Close")
        }
    }

    private var title: String {
        switch model.stage {
        case .drag: "Drag Snaps into the list above"
        case .enable: "Now switch Snaps on"
        case .granted: "Screen Recording is on"
        }
    }

    private var subtitle: String {
        switch model.stage {
        case .drag: "Drop it into Screen & System Audio Recording, then turn on its switch."
        case .enable: "Flip the switch next to Snaps in the list. If macOS asks, choose Quit & Reopen."
        case .granted: "Relaunch Snaps to start capturing."
        }
    }

    @ViewBuilder
    private var icon: some View {
        if model.stage == .granted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white, .green)
                .frame(width: 60, height: 60)
                .transition(.scale.combined(with: .opacity))
        } else {
            // Gentle bob so it reads as "pick me up".
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let bob = model.stage == .drag ? sin(t * 3) * 3 : 0
                ZStack {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    DragSource(
                        fileURL: Bundle.main.bundleURL,
                        image: NSApp.applicationIconImage,
                        inset: 0,
                        onHover: { _ in },
                        onClick: nil,
                        onDoubleClick: {},
                        onDragStart: {},
                        onDragEnd: { dropped in if dropped { onDropped() } }
                    )
                }
                .frame(width: 60, height: 60)
                .offset(y: bob)
            }
            .help("Drag me into the list")
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch model.stage {
        case .drag:
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.tint)
                    .offset(y: -abs(sin(t * 2.6)) * 6)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: .circle)
            }
            .padding(.trailing, 18)
        case .enable:
            Image(systemName: "switch.2")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .glassEffect(.regular, in: .circle)
                .padding(.trailing, 18)
        case .granted:
            Button(action: onRelaunch) {
                Label("Relaunch Snaps", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glassProminent)
            .padding(.trailing, 18)
        }
    }
}
