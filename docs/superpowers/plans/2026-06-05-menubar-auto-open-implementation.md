# Menu Bar Auto-Open Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically open the macOS menu bar popover whenever the Umbra scale transitions from disconnected to connected, including automatic reconnects.

**Architecture:** Replace the current `MenuBarExtra` scene with a small AppKit-owned status item and popover bridge, while keeping `AcaiaScaleManager` as the single source of connection truth. Gate the auto-open behavior through a tiny transition helper so repeated `.connected` updates during an active session do not reopen the popover.

**Tech Stack:** SwiftUI, AppKit, CoreBluetooth, Swift Testing, SwiftPM, Xcodebuild

---

## File Structure

- Create: `UmbraScale/MenuBar/ConnectionTransitionGate.swift`
  Purpose: Pure logic for detecting a `false -> true` connection transition.
- Create: `UmbraScale/MenuBar/ScaleMenuBarController.swift`
  Purpose: Own the `NSStatusItem`, `NSPopover`, and observation of `AcaiaScaleManager`.
- Modify: `UmbraScale/UmbraScaleApp.swift`
  Purpose: Remove `MenuBarExtra`, keep the shared scale manager, and install the new controller.
- Modify: `UmbraScale/ContentView.swift`
  Purpose: Move `MenuBarContent` into a reusable definition or keep it reusable for the new popover host without changing its actions.
- Modify: `UmbraScaleTests/AcaiaPhase1Tests.swift`
  Purpose: Add focused transition-gate coverage.

### Task 1: Add a Testable Connection Transition Gate

**Files:**
- Create: `UmbraScale/MenuBar/ConnectionTransitionGate.swift`
- Modify: `UmbraScaleTests/AcaiaPhase1Tests.swift`
- Test: `UmbraScaleTests/AcaiaPhase1Tests.swift`

- [ ] **Step 1: Write the failing test**

Add these tests to `UmbraScaleTests/AcaiaPhase1Tests.swift`:

```swift
    @Test func connectionTransitionGateTriggersOnlyOnFreshConnect() {
        var gate = ConnectionTransitionGate()

        #expect(gate.consume(isConnected: false) == false)
        #expect(gate.consume(isConnected: true) == true)
        #expect(gate.consume(isConnected: true) == false)
        #expect(gate.consume(isConnected: true) == false)
    }

    @Test func connectionTransitionGateRearmsAfterDisconnect() {
        var gate = ConnectionTransitionGate()

        #expect(gate.consume(isConnected: true) == true)
        #expect(gate.consume(isConnected: false) == false)
        #expect(gate.consume(isConnected: true) == true)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter connectionTransitionGate
```

Expected: FAIL with a compile error that `ConnectionTransitionGate` is not defined.

- [ ] **Step 3: Write minimal implementation**

Create `UmbraScale/MenuBar/ConnectionTransitionGate.swift`:

```swift
import Foundation

struct ConnectionTransitionGate {
    private var wasConnected = false

    mutating func consume(isConnected: Bool) -> Bool {
        defer { wasConnected = isConnected }
        return wasConnected == false && isConnected == true
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --filter connectionTransitionGate
```

Expected: PASS for both new gate tests.

- [ ] **Step 5: Commit**

```bash
git add UmbraScale/MenuBar/ConnectionTransitionGate.swift UmbraScaleTests/AcaiaPhase1Tests.swift
git commit -m "Add connection transition gate"
```

### Task 2: Add an AppKit Menu Bar Controller

**Files:**
- Create: `UmbraScale/MenuBar/ScaleMenuBarController.swift`
- Modify: `UmbraScale/ContentView.swift`
- Test: `UmbraScaleTests/AcaiaPhase1Tests.swift` (existing gate tests remain the automated guard for auto-open behavior)

- [ ] **Step 1: Write the failing integration surface first**

Move `MenuBarContent` out of `UmbraScaleApp.swift` and into `UmbraScale/ContentView.swift` so the new controller can host it as a reusable view:

```swift
struct MenuBarContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scale.connectedDeviceName ?? "Acaia Umbra")
                .font(.headline)
            Text(scale.state.displayText)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f g", scale.displayedReading.grams))
                .font(.title2.monospacedDigit())

            Divider()

            Button("Open Window") {
                openWindow(id: "main")
            }

            Button(scale.isConnected ? "Disconnect" : "Scan") {
                if scale.isConnected {
                    scale.disconnect()
                } else {
                    scale.startScanning()
                }
            }

            Button("Zero Display") {
                scale.zeroDisplay()
            }
            .disabled(!scale.isConnected)

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
```

Then add a controller skeleton in `UmbraScale/MenuBar/ScaleMenuBarController.swift` that intentionally references not-yet-implemented update methods:

```swift
import AppKit
import Combine
import SwiftUI

@MainActor
final class ScaleMenuBarController {
    private let scale: AcaiaScaleManager
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var connectionGate = ConnectionTransitionGate()

    init(scale: AcaiaScaleManager) {
        self.scale = scale
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configurePopover()
        configureButton()
        bindScale()
        refreshStatusItem()
    }
}
```

- [ ] **Step 2: Run build to verify it fails**

Run:

```bash
xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' build
```

Expected: FAIL with missing member errors for `configurePopover`, `configureButton`, `bindScale`, or `refreshStatusItem`.

- [ ] **Step 3: Write minimal implementation**

Fill in `UmbraScale/MenuBar/ScaleMenuBarController.swift` with the bridge behavior:

```swift
import AppKit
import Combine
import SwiftUI

@MainActor
final class ScaleMenuBarController {
    private let scale: AcaiaScaleManager
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var connectionGate = ConnectionTransitionGate()

    init(scale: AcaiaScaleManager) {
        self.scale = scale
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configurePopover()
        configureButton()
        bindScale()
        refreshStatusItem()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 240, height: 220)
        popover.contentViewController = NSHostingController(rootView: MenuBarContent(scale: scale))
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func bindScale() {
        scale.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refreshStatusItem()
            }
            .store(in: &cancellables)

        scale.$state
            .map { _ in self.scale.isConnected }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                guard let self else { return }
                if self.connectionGate.consume(isConnected: isConnected) {
                    self.showPopover()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = scale.menuBarTitle
        button.image = NSImage(
            systemSymbolName: scale.isConnected ? "scalemass.fill" : "scalemass",
            accessibilityDescription: scale.isConnected ? "Connected scale" : "Scale"
        )
        button.imagePosition = .imageLeading
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button, popover.isShown == false else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

Notes for implementation:

- Use `.map { [weak scale] _ in scale?.isConnected ?? false }` if the compiler rejects a strong `self` capture in the Combine chain.
- Keep the title and image formatting aligned with the current `menuBarTitle` and symbol behavior.
- Do not move BLE behavior into this controller.

- [ ] **Step 4: Run build to verify it passes**

Run:

```bash
xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add UmbraScale/MenuBar/ScaleMenuBarController.swift UmbraScale/ContentView.swift
git commit -m "Add AppKit menu bar controller"
```

### Task 3: Wire the App to Use the Controller

**Files:**
- Modify: `UmbraScale/UmbraScaleApp.swift`
- Test: `UmbraScaleTests/AcaiaPhase1Tests.swift`

- [ ] **Step 1: Write the failing app wiring change**

Replace the `MenuBarExtra` scene with a retained controller reference in `UmbraScale/UmbraScaleApp.swift`:

```swift
import SwiftUI

@main
struct UmbraScaleApp: App {
    @StateObject private var scale = AcaiaScaleManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(scale: scale)
                .onAppear {
                    appDelegate.installMenuBarIfNeeded(scale: scale)
                }
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: ScaleMenuBarController?

    @MainActor
    func installMenuBarIfNeeded(scale: AcaiaScaleManager) {
        guard menuBarController == nil else { return }
        menuBarController = ScaleMenuBarController(scale: scale)
    }
}
```

- [ ] **Step 2: Run full tests to verify a failure or regression surface**

Run:

```bash
swift test
```

Expected: PASS for support tests, because the app-entry wiring is excluded from SwiftPM.

Then run:

```bash
xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED. If it fails, fix the reported app-entry or import error before moving on.

- [ ] **Step 3: Write minimal implementation fixes**

Normalize `UmbraScale/UmbraScaleApp.swift` to:

```swift
import AppKit
import SwiftUI

@main
struct UmbraScaleApp: App {
    @StateObject private var scale = AcaiaScaleManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(scale: scale)
                .onAppear {
                    appDelegate.installMenuBarIfNeeded(scale: scale)
                }
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: ScaleMenuBarController?

    @MainActor
    func installMenuBarIfNeeded(scale: AcaiaScaleManager) {
        guard menuBarController == nil else { return }
        menuBarController = ScaleMenuBarController(scale: scale)
    }
}
```

Do not reintroduce `MenuBarExtra`.

- [ ] **Step 4: Run verification**

Run:

```bash
swift test
```

Expected: PASS.

Run:

```bash
xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manual verification**

Run the app from Xcode or with:

```bash
xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' run
```

Then verify:

1. Click the status item manually and confirm the popover opens and closes normally.
2. Connect to the Umbra from the app and confirm the popover opens automatically on successful connection.
3. Leave the scale connected and confirm weight updates do not repeatedly reopen the popover.
4. Disconnect or power off the scale, then let it reconnect automatically and confirm the popover opens again.

- [ ] **Step 6: Commit**

```bash
git add UmbraScale/UmbraScaleApp.swift
git commit -m "Wire app to auto-open menu bar on connect"
```

### Task 4: Final Validation and Cleanup

**Files:**
- Review: `UmbraScale/MenuBar/ConnectionTransitionGate.swift`
- Review: `UmbraScale/MenuBar/ScaleMenuBarController.swift`
- Review: `UmbraScale/UmbraScaleApp.swift`
- Review: `UmbraScale/ContentView.swift`
- Review: `UmbraScaleTests/AcaiaPhase1Tests.swift`

- [ ] **Step 1: Run the focused parser/support tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 2: Run the app build again**

Run:

```bash
xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Review the diff for accidental scope creep**

Run:

```bash
git diff --stat 54e30b6..HEAD
git diff -- UmbraScale/MenuBar/ConnectionTransitionGate.swift UmbraScale/MenuBar/ScaleMenuBarController.swift UmbraScale/UmbraScaleApp.swift UmbraScale/ContentView.swift UmbraScaleTests/AcaiaPhase1Tests.swift
```

Expected: Only menu bar presentation, app wiring, and gate-test changes. No BLE parser or entitlement drift.

- [ ] **Step 4: Create the final commit**

```bash
git add UmbraScale/MenuBar/ConnectionTransitionGate.swift UmbraScale/MenuBar/ScaleMenuBarController.swift UmbraScale/UmbraScaleApp.swift UmbraScale/ContentView.swift UmbraScaleTests/AcaiaPhase1Tests.swift
git commit -m "Auto-open menu bar when scale connects"
```
