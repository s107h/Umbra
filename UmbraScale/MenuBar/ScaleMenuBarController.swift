import AppKit
import Combine
import SwiftUI

@MainActor
final class ScaleMenuBarController: NSObject {
    let statusItem: NSStatusItem
    let popover: NSPopover
    let hostingController: NSHostingController<ScaleMenuBarContent>

    private let scale: AcaiaScaleManager
    private let kettle: FellowKettleManager
    private let kettleBLEResearch: FellowKettleBLEResearchManager
    private var presentationState = ScaleHUDPresentationState()
    private var cancellables: Set<AnyCancellable> = []
    private lazy var hudWindowController = ScaleHUDWindowController(
        rootView: makeHUDRootView(mode: presentationState.mode)
    )

    init(scale: AcaiaScaleManager, kettle: FellowKettleManager, kettleBLEResearch: FellowKettleBLEResearchManager) {
        self.scale = scale
        self.kettle = kettle
        self.kettleBLEResearch = kettleBLEResearch
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        hostingController = NSHostingController(
            rootView: ScaleMenuBarContent(scale: scale, onOpenExpandedHUD: {})
        )

        super.init()

        configureStatusItem()
        configurePopover()
        configurePopoverRootView()
        observeScale()
        refreshMenuBarPresentation()
    }

    @objc
    func togglePopover(_ sender: Any?) {
        if scale.isConnected {
            bringHUDToFront()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        refreshPopoverSize()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.title = ""
        button.imagePosition = .imageOnly
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
        refreshPopoverSize()
    }

    private func configurePopoverRootView() {
        hostingController.rootView = ScaleMenuBarContent(
            scale: scale,
            onOpenExpandedHUD: { [weak self] in
                self?.popover.performClose(nil)
                self?.openExpandedHUDFromPopup()
            }
        )
        refreshPopoverSize()
    }

    private func observeScale() {
        scale.$state
            .sink { [weak self] _ in
                guard let self else { return }
                refreshMenuBarPresentation()
                applyPresentationAction(presentationState.handleConnectionChange(isConnected: scale.isConnected))
            }
            .store(in: &cancellables)

        scale.$reading
            .sink { [weak self] _ in
                self?.refreshMenuBarPresentation()
                self?.refreshHUDRootView()
            }
            .store(in: &cancellables)

        scale.$zeroOffsetGrams
            .sink { [weak self] _ in
                self?.refreshMenuBarPresentation()
                self?.refreshHUDRootView()
            }
            .store(in: &cancellables)

        scale.$connectedDeviceName
            .sink { [weak self] _ in
                self?.refreshPopoverSize()
                self?.refreshHUDRootView()
            }
            .store(in: &cancellables)

        scale.objectWillChange
            .sink { [weak self] in
                self?.refreshHUDRootView()
            }
            .store(in: &cancellables)
    }

    private func refreshMenuBarPresentation() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = NSImage(
            systemSymbolName: scale.isConnected ? "scalemass.fill" : "scalemass",
            accessibilityDescription: scale.isConnected ? "Scale connected" : "Scale disconnected"
        )
        refreshPopoverSize()
    }

    private func openExpandedHUDFromPopup() {
        applyPresentationAction(presentationState.openExpandedFromPopup())
    }

    private func bringHUDToFront() {
        if presentationState.isHUDVisible {
            hudWindowController.bringToFront()
        } else {
            applyPresentationAction(.showCenteredAndActivate(mode: presentationState.mode))
        }
    }

    private func toggleHUDMode() {
        applyPresentationAction(presentationState.toggleExpandedMode())
    }

    private func applyPresentationAction(_ action: ScaleHUDPresentationAction) {
        switch action {
        case .none:
            refreshHUDRootView()
        case .showCenteredAndActivate(let mode):
            refreshHUDRootView(mode: mode)
            hudWindowController.showCentered(mode: mode)
        case .resizeHUD(let mode):
            refreshHUDRootView(mode: mode)
            hudWindowController.resize(to: mode)
            hudWindowController.bringToFront()
        case .dismissHUD:
            hudWindowController.dismiss()
        }
    }

    private func makeHUDRootView(mode: ScaleHUDMode) -> ScaleHUDRootView {
        ScaleHUDRootView(
            scale: scale,
            kettle: kettle,
            kettleBLEResearch: kettleBLEResearch,
            mode: mode,
            onToggleGear: { [weak self] in
                self?.toggleHUDMode()
            }
        )
    }

    private func refreshHUDRootView(mode: ScaleHUDMode? = nil) {
        let resolvedMode = mode ?? presentationState.mode
        hudWindowController.update(rootView: makeHUDRootView(mode: resolvedMode))
    }

    private func refreshPopoverSize() {
        let view = hostingController.view
        view.layoutSubtreeIfNeeded()
        let fittingSize = view.fittingSize

        guard fittingSize.width > 0, fittingSize.height > 0 else { return }
        popover.contentSize = fittingSize
    }
}
