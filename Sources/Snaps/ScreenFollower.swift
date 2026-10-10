import AppKit

/// Reports when the cursor moves to a different display, so floating UI can follow it.
/// Only runs while something is on screen.
@MainActor
final class ScreenFollower {
    private var timer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var currentID: CGDirectDisplayID?
    private let onChange: (NSScreen) -> Void

    init(onChange: @escaping (NSScreen) -> Void) {
        self.onChange = onChange
    }

    var isRunning: Bool { timer != nil }

    func start(on screen: NSScreen?) {
        currentID = screen?.displayID
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check(force: false) }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Displays plugged in, removed or rearranged.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.check(force: true) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    private func check(force: Bool) {
        // Don't move things mid-drag (e.g. while dragging a capture onto the other display).
        guard NSEvent.pressedMouseButtons == 0, let screen = NSScreen.underMouse else { return }
        guard force || screen.displayID != currentID else { return }
        currentID = screen.displayID
        onChange(screen)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
