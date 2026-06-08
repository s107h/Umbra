# Menu Bar HUD Refactor Design

## Goal

Refactor UmbraScale into a menu-bar-first macOS app with:

- a glyph-only menu bar item
- a small disconnected popup
- a centered draggable HUD window that becomes the primary app surface

The HUD should automatically appear and activate the app on successful connection, remain visible while connected, and dismiss on disconnect. The HUD should support compact and expanded modes, with the expanded mode replacing the old standalone main app window.

## Scope

In scope:

- Remove the `Umbra` word from the menu bar item so only the scale glyph remains.
- Replace the persistent connected popover concept with a separate centered HUD window.
- Keep a small disconnected popup accessible from the menu bar glyph.
- Make the HUD draggable by the user.
- Auto-show the HUD and activate the app on connection.
- Auto-dismiss the HUD on disconnect.
- Add compact and expanded HUD modes toggled by a gear button.
- Move the current device list and debug log into the expanded HUD.
- Remove the standalone main app window from the app interaction model.

Out of scope:

- BLE protocol changes.
- Packet parsing changes.
- New tare behavior.
- Changes to Bluetooth entitlements or privacy strings.
- Hiding or reducing BLE logging.

## Current State

The app currently uses:

- an AppKit `NSStatusItem` with `NSPopover`
- a SwiftUI `ScaleMenuBarContent` popover body
- a `WindowGroup`-backed main app window for the full controls and logs
- `AcaiaScaleManager` as the source of truth for Bluetooth state, readings, discovered devices, and logs

The current structure already has the right separation between BLE state and UI state, but the presentation model still assumes:

- a text-plus-glyph menu bar item
- a menu-attached popover for connected interactions
- a separate main window for the full tool surface

This design replaces that with a centered HUD window as the primary interface.

## Approaches Considered

### Recommended: Dedicated centered HUD window

Use the existing AppKit presentation layer as the basis for:

- a glyph-only `NSStatusItem`
- a compact disconnected popup
- a separate HUD window centered on the main display

Benefits:

- Supports a true persistent connected interface without abusing popover behavior.
- Allows dragging and activation behavior that matches the requested UX.
- Keeps BLE logic isolated from presentation concerns.
- Lets the expanded HUD replace the main window cleanly.

Tradeoffs:

- Requires a new window controller and explicit HUD lifecycle management.
- Requires refactoring the current `ContentView` into reusable HUD sections.

### Rejected: Persistent menu-attached popover

Keep everything attached to the menu bar and make the popover remain open while connected.

Why rejected:

- It does not match the requested centered floating HUD behavior.
- It is a poor fit for draggable interaction.
- It keeps the UI constrained by popover behavior rather than using a proper window.

### Rejected: Separate compact HUD plus second settings window

Use one compact HUD for live weight and open another window for settings/debug.

Why rejected:

- Adds unnecessary window-management complexity.
- Breaks the requested single-surface expand/collapse interaction around the gear button.

## Design

### 1. App surface model

The app will become menu-bar-first and will no longer present a standalone main app window.

The UI surfaces will be:

- `NSStatusItem` with glyph only
- small disconnected popup
- centered draggable HUD window

The menu bar icon remains the always-available entry point. The HUD window becomes the primary operational interface.

### 2. Menu bar behavior

The status item should:

- show only the scale glyph
- open a small popup when clicked
- keep that popup available while disconnected

The disconnected popup should show:

- a large `Disconnected` label
- a gear button

The disconnected popup should not show the old action list or the `Umbra` label. Its job is only to communicate state and provide the path into the expanded HUD.

### 3. HUD behavior

The HUD window should:

- appear centered on the main display on successful connection
- activate the app and come to the front when shown automatically
- remain visible for the full connected session
- dismiss automatically when the scale disconnects
- be draggable by the user

The HUD should support two modes:

- `compact`
- `expanded`

#### Compact mode

Compact mode is the default connected presentation.

It shows:

- large live weight text when connected
- gear button for expansion

If the HUD is opened from disconnected state through the popup gear, it should open directly in expanded mode rather than showing a disconnected compact HUD first.

#### Expanded mode

Expanded mode is the full app interface and replaces the old main window.

It shows:

- connection status
- live weight if connected, or disconnected state if not
- scan, stop, disconnect, and related operational controls as appropriate
- discovered device list
- debug log
- log copy and clear actions if they still fit naturally

The gear button toggles between compact and expanded modes in the same HUD window. Expanding should resize the existing HUD in place rather than opening a second window.

### 4. Settings and gear behavior

The gear button always means "show the expanded HUD surface."

Behavior by context:

- from disconnected popup: open centered HUD in expanded mode
- from connected compact HUD: expand the current HUD in place
- from connected expanded HUD: collapse back to compact mode

This creates one consistent interaction model instead of routing some paths to a separate app window.

### 5. Content structure refactor

The current `ContentView` should not be transplanted wholesale into the HUD. Instead, the UI should be refactored into smaller SwiftUI sections so the HUD can assemble:

- compact live-weight content
- expanded control content
- expanded device list content
- expanded debug log content

This keeps the compact surface focused and prevents the expanded surface from inheriting window-specific assumptions from the old layout.

The BLE manager remains unchanged as the owner of:

- Bluetooth availability state
- scanning and connection state
- discovered devices
- current reading
- zero offset state
- debug log contents

### 6. Presentation ownership

Presentation logic belongs in the menu/HUD controller layer, not in `AcaiaScaleManager`.

That layer should own:

- popup visibility
- HUD creation and destruction
- HUD mode (`compact` or `expanded`)
- centering and activation behavior
- connection-driven auto-show
- disconnect-driven dismissal

This keeps the BLE layer testable and free of AppKit-specific concerns.

### 7. Windowing details

The HUD should be implemented as a focused floating AppKit window hosting SwiftUI content.

Important behavior:

- centered on the main display when first shown
- draggable after appearing
- resizable by code between compact and expanded dimensions
- single-window lifecycle across a connection session

The disconnected popup remains a popover-style surface because it is intentionally small and menu-adjacent. The connected HUD should not be modeled as a popover.

## Testing

### Automated

Keep existing BLE and parser tests unchanged unless the refactor requires touching parser-adjacent code.

Add focused automated coverage where practical for presentation-state rules such as:

- connect transition requests HUD show
- disconnect requests HUD dismissal
- gear toggles `compact` and `expanded`
- disconnected gear request opens expanded HUD state

The presentation logic should be decomposed enough to test state transitions without requiring full live AppKit interaction in every case.

### Manual

1. Launch the app.
2. Verify the menu bar item shows only the scale glyph.
3. Click the glyph while disconnected and verify the popup shows a large `Disconnected` label and gear button.
4. Click the gear while disconnected and verify the centered HUD opens in expanded mode.
5. Start scanning and connect to the Umbra.
6. Verify the app activates and the HUD appears centered on the main display.
7. Verify the HUD shows compact live weight by default on successful connection.
8. Drag the HUD and verify it remains movable.
9. Click the gear and verify the HUD expands in place to show controls, device list, and debug log.
10. Click the gear again and verify the HUD collapses back to compact mode.
11. Disconnect or power off the scale and verify the HUD dismisses automatically.

## Risks

- Removing the standalone main window changes app-scene assumptions and may require careful SwiftUI/AppKit lifecycle wiring.
- A floating HUD window can feel intrusive if sizing or activation behavior is not tuned carefully.
- Moving all diagnostic tools into the expanded HUD increases the importance of clean layout decomposition.

These risks are contained because the BLE stack, parser boundaries, and logging model stay intact.

## Implementation Notes

- Keep BLE packet parsing isolated in its current testable parser type.
- Preserve logging for services, characteristics, notification payloads, and connection state.
- Do not remove Bluetooth entitlement or privacy usage strings.
- Build the refactor incrementally and keep commits small and reviewable.
