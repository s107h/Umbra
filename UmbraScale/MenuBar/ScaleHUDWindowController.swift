import AppKit
import SwiftUI

@MainActor
final class ScaleHUDWindowController: NSWindowController {
    private let hostingController: NSHostingController<ScaleHUDRootView>

    init(rootView: ScaleHUDRootView) {
        hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: ScaleHUDMode.compact.contentSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentViewController = hostingController

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(rootView: ScaleHUDRootView) {
        hostingController.rootView = rootView
    }

    func showCentered(mode: ScaleHUDMode) {
        resize(to: mode, animate: false)
        centerOnMainScreen()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func resize(to mode: ScaleHUDMode, animate: Bool = true) {
        guard let window else { return }
        let currentFrame = window.frame
        let newSize = mode.contentSize
        let newOrigin = CGPoint(
            x: currentFrame.midX - (newSize.width / 2),
            y: currentFrame.midY - (newSize.height / 2)
        )
        let newFrame = CGRect(origin: newOrigin, size: newSize)
        window.setFrame(newFrame, display: true, animate: animate)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func centerOnMainScreen() {
        guard let screen = NSScreen.main, let window else { return }
        let frame = window.frame
        let origin = CGPoint(
            x: screen.frame.midX - (frame.width / 2),
            y: screen.frame.midY - (frame.height / 2)
        )
        window.setFrameOrigin(origin)
    }
}
