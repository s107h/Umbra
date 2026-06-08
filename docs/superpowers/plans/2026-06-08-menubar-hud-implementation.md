# Menu Bar HUD Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the text-plus-popover plus main-window app shell with a glyph-only menu bar item, a compact disconnected popup, and a centered draggable HUD window that becomes the primary interface.

**Architecture:** Keep `AcaiaScaleManager` as the BLE/data source and move all menu/HUD lifecycle decisions into AppKit-owned presentation types. Refactor the current full-window SwiftUI into reusable HUD sections so the same scale state can drive compact connected, expanded connected, and expanded disconnected interfaces without restoring a standalone `WindowGroup`.

**Tech Stack:** SwiftUI, AppKit, Combine, CoreBluetooth, Swift Testing, Xcodebuild, SwiftPM tests

---

## File Structure

### New files

- `UmbraScale/MenuBar/ScaleHUDMode.swift`
  - HUD mode enum and compact/expanded sizing constants.
- `UmbraScale/MenuBar/ScaleHUDWindowController.swift`
  - AppKit window lifecycle for centering, showing, resizing, dragging, and dismissal.
- `UmbraScale/MenuBar/ScaleHUDRootView.swift`
  - Top-level SwiftUI HUD body that switches between compact and expanded content.
- `UmbraScale/MenuBar/ScaleHUDCompactContent.swift`
  - Large live-weight or disconnected compact display plus gear button.
- `UmbraScale/MenuBar/ScaleHUDExpandedContent.swift`
  - Expanded HUD layout that replaces the old main window.
- `UmbraScale/MenuBar/ScaleHUDSections.swift`
  - Reusable SwiftUI sections for status, controls, discovered devices, and debug log.
- `UmbraScaleTests/ScaleHUDPresentationTests.swift`
  - Tests for connection-driven HUD show/dismiss and gear-driven mode changes.

### Modified files

- `UmbraScale/UmbraScaleApp.swift`
  - Remove the main `WindowGroup` dependency and initialize the menu/HUD shell directly.
- `UmbraScale/MenuBar/ScaleMenuBarController.swift`
  - Change the status item to glyph-only, keep the disconnected popup, and coordinate the HUD window.
- `UmbraScale/MenuBar/ScaleMenuBarContent.swift`
  - Reduce popup content to large disconnected status plus gear button.
- `UmbraScale/ContentView.swift`
  - Shrink to a reusable expanded HUD composition or replace with a thin wrapper around new sections.
- `UmbraScale.xcodeproj/project.pbxproj`
  - Add the new menu/HUD Swift files and the new test file to the Xcode target and test target.
- `UmbraScaleTests/AcaiaPhase1Tests.swift`
  - Remove `ConnectionTransitionGate` assertions if those rules move into the new presentation tests.
- `docs/phase1_manual_test_steps.md`
  - Add HUD-specific manual verification steps.

## Task 1: Add Testable HUD Presentation State

**Files:**
- Create: `UmbraScale/MenuBar/ScaleHUDMode.swift`
- Create: `UmbraScaleTests/ScaleHUDPresentationTests.swift`
- Modify: `UmbraScaleTests/AcaiaPhase1Tests.swift`
- Modify: `UmbraScale.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing HUD presentation tests**

```swift
import Testing
@testable import UmbraScaleSupport

struct ScaleHUDPresentationTests {
    @Test func connectTransitionShowsCompactHUD() {
        var state = ScaleHUDPresentationState()

        let action = state.handleConnectionChange(isConnected: true)

        #expect(action == .showCenteredAndActivate(mode: .compact))
        #expect(state.isHUDVisible)
        #expect(state.mode == .compact)
    }

    @Test func disconnectDismissesVisibleHUD() {
        var state = ScaleHUDPresentationState(isHUDVisible: true, mode: .expanded)

        let action = state.handleConnectionChange(isConnected: false)

        #expect(action == .dismissHUD)
        #expect(!state.isHUDVisible)
    }

    @Test func popupGearOpensExpandedHUDWhileDisconnected() {
        var state = ScaleHUDPresentationState()

        let action = state.openExpandedFromPopup()

        #expect(action == .showCenteredAndActivate(mode: .expanded))
        #expect(state.isHUDVisible)
        #expect(state.mode == .expanded)
    }

    @Test func gearTogglesBetweenCompactAndExpandedModes() {
        var state = ScaleHUDPresentationState(isHUDVisible: true, mode: .compact)

        #expect(state.toggleExpandedMode() == .resizeHUD(mode: .expanded))
        #expect(state.toggleExpandedMode() == .resizeHUD(mode: .compact))
    }
}
```

- [ ] **Step 2: Run SwiftPM tests to verify the new tests fail**

Run: `swift test --filter ScaleHUDPresentationTests`

Expected: FAIL with compile errors such as `cannot find 'ScaleHUDPresentationState' in scope`

- [ ] **Step 3: Implement the minimal HUD mode and presentation state**

```swift
import CoreGraphics

enum ScaleHUDMode: Equatable {
    case compact
    case expanded

    var contentSize: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 280, height: 180)
        case .expanded:
            return CGSize(width: 760, height: 620)
        }
    }
}

enum ScaleHUDPresentationAction: Equatable {
    case none
    case showCenteredAndActivate(mode: ScaleHUDMode)
    case resizeHUD(mode: ScaleHUDMode)
    case dismissHUD
}

struct ScaleHUDPresentationState: Equatable {
    var wasConnected = false
    var isHUDVisible = false
    var mode: ScaleHUDMode = .compact

    mutating func handleConnectionChange(isConnected: Bool) -> ScaleHUDPresentationAction {
        defer { wasConnected = isConnected }

        if !wasConnected && isConnected {
            isHUDVisible = true
            mode = .compact
            return .showCenteredAndActivate(mode: .compact)
        }

        if wasConnected && !isConnected {
            isHUDVisible = false
            return .dismissHUD
        }

        return .none
    }

    mutating func openExpandedFromPopup() -> ScaleHUDPresentationAction {
        isHUDVisible = true
        mode = .expanded
        return .showCenteredAndActivate(mode: .expanded)
    }

    mutating func toggleExpandedMode() -> ScaleHUDPresentationAction {
        mode = (mode == .compact) ? .expanded : .compact
        return .resizeHUD(mode: mode)
    }
}
```

- [ ] **Step 4: Remove or narrow the old connection-gate test if it is superseded**

```swift
// Delete these tests from AcaiaPhase1Tests.swift if the new presentation tests
// fully cover the behavior:
// - connectionTransitionGateTriggersOnlyOnFreshConnect
// - connectionTransitionGateRearmsAfterDisconnect
```

- [ ] **Step 5: Run the full SwiftPM test suite**

Run: `swift test`

Expected: PASS with `Test run with 0 failures` or the Swift Testing equivalent summary

- [ ] **Step 6: Commit the testable presentation-state slice**

```bash
git add UmbraScale/MenuBar/ScaleHUDMode.swift \
        UmbraScaleTests/ScaleHUDPresentationTests.swift \
        UmbraScaleTests/AcaiaPhase1Tests.swift \
        UmbraScale.xcodeproj/project.pbxproj
git commit -m "Add HUD presentation state"
```

## Task 2: Replace The Popup Contract And Status Item Label

**Files:**
- Modify: `UmbraScale/MenuBar/ScaleMenuBarContent.swift`
- Modify: `UmbraScale/MenuBar/ScaleMenuBarController.swift`
- Test: `UmbraScaleTests/ScaleHUDPresentationTests.swift`

- [ ] **Step 1: Add a failing popup-content assertion for the disconnected path**

```swift
@Test func popupGearAlwaysRequestsExpandedHUD() {
    var state = ScaleHUDPresentationState()

    let action = state.openExpandedFromPopup()

    #expect(action == .showCenteredAndActivate(mode: .expanded))
}
```

- [ ] **Step 2: Run the focused test to confirm the current UI contract is not yet implemented**

Run: `swift test --filter popupGearAlwaysRequestsExpandedHUD`

Expected: PASS for state logic, while the UI is still unchanged in the app target

- [ ] **Step 3: Rewrite the popup SwiftUI view to show only disconnected state and a gear button**

```swift
import SwiftUI

struct ScaleMenuBarContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    let onOpenExpandedHUD: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(scale.isConnected ? String(format: "%.1f g", scale.displayedReading.grams) : "Disconnected")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button(action: onOpenExpandedHUD) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 220)
    }
}
```

- [ ] **Step 4: Make the status item glyph-only and route popup gear clicks into the HUD flow**

```swift
private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.target = self
    button.action = #selector(togglePopover(_:))
    button.title = ""
    button.imagePosition = .imageOnly
}

private func refreshMenuBarPresentation() {
    guard let button = statusItem.button else { return }
    button.title = ""
    button.image = NSImage(
        systemSymbolName: scale.isConnected ? "scalemass.fill" : "scalemass",
        accessibilityDescription: scale.isConnected ? "Scale connected" : "Scale disconnected"
    )
}
```

- [ ] **Step 5: Rebuild the popup root view injection to use the new HUD action**

```swift
hostingController.rootView = ScaleMenuBarContent(
    scale: scale,
    onOpenExpandedHUD: { [weak self] in
        self?.popover.performClose(nil)
        self?.applyPresentationAction(self?.presentationState.openExpandedFromPopup() ?? .none)
    }
)
```

- [ ] **Step 6: Run SwiftPM tests after the popup contract change**

Run: `swift test --filter ScaleHUDPresentationTests`

Expected: PASS

- [ ] **Step 7: Commit the menu bar glyph and popup simplification**

```bash
git add UmbraScale/MenuBar/ScaleMenuBarContent.swift \
        UmbraScale/MenuBar/ScaleMenuBarController.swift
git commit -m "Simplify menu bar popup for HUD flow"
```

## Task 3: Build The HUD Window And Compact/Expanded Content

**Files:**
- Create: `UmbraScale/MenuBar/ScaleHUDWindowController.swift`
- Create: `UmbraScale/MenuBar/ScaleHUDRootView.swift`
- Create: `UmbraScale/MenuBar/ScaleHUDCompactContent.swift`
- Create: `UmbraScale/MenuBar/ScaleHUDExpandedContent.swift`
- Create: `UmbraScale/MenuBar/ScaleHUDSections.swift`
- Modify: `UmbraScale/MenuBar/ScaleMenuBarController.swift`
- Modify: `UmbraScale/ContentView.swift`
- Modify: `UmbraScale.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing Xcode build before adding the new HUD files**

Run: `xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -configuration Debug build`

Expected: PASS before the refactor, giving a clean baseline

- [ ] **Step 2: Add the AppKit HUD window controller**

```swift
import AppKit
import SwiftUI

@MainActor
final class ScaleHUDWindowController: NSWindowController {
    private let hostingController: NSHostingController<ScaleHUDRootView>

    init(rootView: ScaleHUDRootView) {
        self.hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: ScaleHUDMode.compact.contentSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.contentViewController = hostingController

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func showCentered(mode: ScaleHUDMode) {
        resize(to: mode)
        centerOnMainScreen()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func resize(to mode: ScaleHUDMode) {
        guard let window else { return }
        let newFrame = CGRect(origin: window.frame.origin, size: mode.contentSize)
        window.setFrame(newFrame, display: true, animate: true)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    private func centerOnMainScreen() {
        guard let screen = NSScreen.main, let window else { return }
        let origin = CGPoint(
            x: screen.frame.midX - (window.frame.width / 2),
            y: screen.frame.midY - (window.frame.height / 2)
        )
        window.setFrameOrigin(origin)
    }
}
```

- [ ] **Step 3: Add the compact and expanded HUD SwiftUI views**

```swift
import SwiftUI

struct ScaleHUDRootView: View {
    @ObservedObject var scale: AcaiaScaleManager
    let mode: ScaleHUDMode
    let onToggleGear: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .compact:
                ScaleHUDCompactContent(scale: scale, onToggleGear: onToggleGear)
            case .expanded:
                ScaleHUDExpandedContent(scale: scale, onToggleGear: onToggleGear)
            }
        }
        .padding(20)
    }
}

struct ScaleHUDCompactContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    let onToggleGear: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(String(format: "%.1f g", scale.displayedReading.grams))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack {
                Spacer()
                Button(action: onToggleGear) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 4: Refactor the old full-window UI into reusable expanded HUD sections**

```swift
struct ScaleHUDExpandedContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    let onToggleGear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(scale.state.displayText).font(.title2.weight(.semibold))
                Spacer()
                Button(action: onToggleGear) {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(.plain)
            }

            ScaleStatusSection(scale: scale)
            ScaleControlsSection(scale: scale)
            DiscoveredScalesSection(scale: scale)
            DebugLogSection(scale: scale)
        }
        .frame(minWidth: 760, minHeight: 620)
    }
}
```

- [ ] **Step 5: Replace `ContentView` with a thin wrapper or remove its unique layout role**

```swift
struct ContentView: View {
    @ObservedObject var scale: AcaiaScaleManager

    var body: some View {
        ScaleHUDExpandedContent(scale: scale, onToggleGear: {})
            .padding(24)
    }
}
```

- [ ] **Step 6: Wire the menu controller to create, update, and dismiss the HUD**

```swift
private var presentationState = ScaleHUDPresentationState()
private lazy var hudWindowController = ScaleHUDWindowController(
    rootView: ScaleHUDRootView(
        scale: scale,
        mode: presentationState.mode,
        onToggleGear: { [weak self] in self?.toggleHUDMode() }
    )
)

private func toggleHUDMode() {
    let action = presentationState.toggleExpandedMode()
    applyPresentationAction(action)
}

private func applyPresentationAction(_ action: ScaleHUDPresentationAction) {
    switch action {
    case .none:
        break
    case .showCenteredAndActivate(let mode):
        updateHUDRootView(mode: mode)
        hudWindowController.showCentered(mode: mode)
    case .resizeHUD(let mode):
        updateHUDRootView(mode: mode)
        hudWindowController.resize(to: mode)
    case .dismissHUD:
        hudWindowController.dismiss()
    }
}
```

- [ ] **Step 7: Run an app build after the HUD refactor**

Run: `xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -configuration Debug build`

Expected: PASS

- [ ] **Step 8: Commit the HUD window and content refactor**

```bash
git add UmbraScale/MenuBar/ScaleHUDWindowController.swift \
        UmbraScale/MenuBar/ScaleHUDRootView.swift \
        UmbraScale/MenuBar/ScaleHUDCompactContent.swift \
        UmbraScale/MenuBar/ScaleHUDExpandedContent.swift \
        UmbraScale/MenuBar/ScaleHUDSections.swift \
        UmbraScale/MenuBar/ScaleMenuBarController.swift \
        UmbraScale/ContentView.swift \
        UmbraScale.xcodeproj/project.pbxproj
git commit -m "Add centered HUD window"
```

## Task 4: Remove The Standalone Main Window And Update Verification Docs

**Files:**
- Modify: `UmbraScale/UmbraScaleApp.swift`
- Modify: `docs/phase1_manual_test_steps.md`
- Modify: `UmbraScale.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the scene-layer change to remove the `WindowGroup` dependency**

```swift
import SwiftUI

@main
struct UmbraScaleApp: App {
    @StateObject private var scale: AcaiaScaleManager
    private let menuBarController: ScaleMenuBarController

    @MainActor
    init() {
        let scale = AcaiaScaleManager()
        _scale = StateObject(wrappedValue: scale)
        menuBarController = ScaleMenuBarController(scale: scale)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 2: Make sure the menu controller no longer depends on `setOpenMainWindowAction`**

```swift
// Delete:
// - private var openMainWindow: () -> Void = {}
// - func setOpenMainWindowAction(_ action: @escaping () -> Void)
// - any remaining popup button that says "Open Window"
```

- [ ] **Step 3: Update the manual-test doc for the new HUD lifecycle**

```markdown
## Menu bar HUD flow

1. Launch UmbraScale and verify only the scale glyph appears in the macOS menu bar.
2. Click the glyph while disconnected and verify the popup shows `Disconnected` and a gear button.
3. Click the gear and verify the centered expanded HUD opens.
4. Connect to the scale and verify the app activates with the compact HUD centered on the main display.
5. Drag the HUD and verify it remains movable.
6. Toggle the gear to expand and collapse the HUD in place.
7. Disconnect the scale and verify the HUD dismisses automatically.
```

- [ ] **Step 4: Run both automated verification commands**

Run: `swift test && xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -configuration Debug build`

Expected: both commands PASS

- [ ] **Step 5: Commit the app-shell removal and docs update**

```bash
git add UmbraScale/UmbraScaleApp.swift \
        docs/phase1_manual_test_steps.md \
        UmbraScale/MenuBar/ScaleMenuBarController.swift
git commit -m "Finish menu bar HUD app shell"
```

## Spec Coverage Check

- Glyph-only menu bar item: Task 2.
- Small disconnected popup with large label and gear: Task 2.
- Centered draggable HUD window: Task 3.
- App activation on connect: Task 3.
- HUD stays visible while connected and dismisses on disconnect: Tasks 1 and 3.
- Gear toggles expanded HUD and opens expanded HUD from disconnected state: Tasks 1, 2, and 3.
- Device list and debug log move into the HUD: Task 3.
- Standalone main app window removed: Task 4.
- Manual validation updates: Task 4.

## Placeholder Scan

- No `TODO`, `TBD`, or deferred “handle later” markers remain.
- Every task includes concrete files, commands, and code snippets.
- Each verification step names the exact command to run.

## Type Consistency Check

- Presentation logic uses `ScaleHUDMode`, `ScaleHUDPresentationAction`, and `ScaleHUDPresentationState` consistently across tests and controller wiring.
- The controller entrypoint for popup gear clicks is `openExpandedFromPopup()`.
- HUD mode toggling is consistently routed through `toggleExpandedMode()`.
