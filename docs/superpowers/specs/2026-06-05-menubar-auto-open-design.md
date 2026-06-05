# Menu Bar Auto-Open On Scale Connection

## Goal

When the Umbra scale reaches a successful connected state, the menu bar UI should automatically open as if the user clicked the status item. This should happen for both manual connections and automatic reconnects.

## Scope

In scope:

- Open the menu bar interface on each transition from not connected to connected.
- Support both explicit user-initiated connects and background auto-reconnects.
- Preserve the existing menu bar content and actions.
- Keep connection-state ownership in `AcaiaScaleManager`.
- Keep BLE parsing and connection logging behavior unchanged.

Out of scope:

- Changing BLE discovery, handshake, or weight parsing behavior.
- Changing the main window behavior.
- Adding user preferences for suppressing the auto-open behavior.

## Current State

The app currently uses SwiftUI `MenuBarExtra` in `UmbraScaleApp.swift` and renders the menu content through `MenuBarContent`. `AcaiaScaleManager` publishes the connection state and updates it repeatedly during the BLE lifecycle, including multiple `.connected(name:)` assignments after characteristics, notifications, and weight packets.

That state model is suitable for determining when a connection succeeds, but the current pure-SwiftUI menu bar scene does not expose a reliable, explicit way to open the menu programmatically.

## Approaches Considered

### Recommended: AppKit-owned status item and popover

Replace the current SwiftUI-managed presentation layer with a small AppKit controller that owns:

- an `NSStatusItem`
- an `NSPopover`
- an `NSHostingController` wrapping the existing SwiftUI menu content

Benefits:

- Explicit programmatic `show` control for automatic opening.
- Stable AppKit API surface for menu bar interaction.
- Keeps the BLE manager and the SwiftUI content mostly unchanged.

Tradeoffs:

- Adds a small bridge layer between SwiftUI `App` and AppKit menu bar presentation.
- Slightly more setup code than the current `MenuBarExtra`.

### Rejected: Synthesize a click into `MenuBarExtra`

Try to locate the underlying status item or button backing `MenuBarExtra` and trigger it indirectly.

Why rejected:

- Depends on undocumented implementation details.
- More likely to break across macOS or SwiftUI updates.
- Harder to reason about and test.

## Design

### Presentation architecture

Add a focused menu bar presentation controller on the app side. It will:

- create the status item and assign title/image based on `AcaiaScaleManager`
- host `MenuBarContent` inside an `NSPopover`
- toggle the popover on manual status-item clicks
- observe the scale manager's connection state and open the popover on a qualifying connection transition

The SwiftUI app remains the entry point and still owns the shared `AcaiaScaleManager` instance.

### Connection transition rule

Auto-open should happen only when the app crosses from "not connected" to "connected".

Implementation rule:

- Track the previous connected boolean in the presentation controller.
- On each relevant state publication, compare previous and current values.
- Open the popover only when `previous == false` and `current == true`.

This avoids reopening on:

- weight updates while already connected
- repeated `.connected(name:)` assignments during an already-active session
- menu content refreshes unrelated to connection transitions

It intentionally does reopen after:

- a disconnect followed by a fresh manual reconnect
- a disconnect followed by a successful automatic reconnect

### Menu content reuse

Keep `MenuBarContent` as the SwiftUI view for the popover body. Reuse the existing actions:

- open main window
- scan or disconnect
- zero display
- quit

The title and icon formatting logic should stay derived from `AcaiaScaleManager` so the status item reflects live weight and connection status the same way the current `MenuBarExtra` label does.

### State observation

Observation belongs in the presentation layer, not in `AcaiaScaleManager`.

Reasoning:

- `AcaiaScaleManager` should continue to describe BLE and connection state, not menu bar presentation policy.
- The auto-open behavior is a UI reaction to connection success.
- This keeps the BLE layer testable and avoids adding AppKit dependencies to Bluetooth code.

## Testing

### Automated

Add a focused test for the transition gate logic:

- false -> true triggers one auto-open request
- true -> true does not trigger another auto-open request
- true -> false resets the gate for a later reconnect
- false -> false does nothing

This can be implemented by extracting the transition decision into a small testable helper or by testing a lightweight presentation-model object without requiring live AppKit popover display.

### Manual

1. Launch the app.
2. Turn on the Umbra and connect manually from the app.
3. Verify the menu bar popover opens automatically on successful connection.
4. Disconnect the scale or power it off.
5. Restore the scale so the app auto-reconnects.
6. Verify the menu bar popover opens automatically again.
7. While connected, confirm ongoing weight updates do not repeatedly reopen the popover.

## Risks

- AppKit lifecycle wiring can be slightly finicky in a SwiftUI app, especially around when the status item and popover are created.
- If the current app structure assumes `MenuBarExtra` behavior in subtle ways, there may be minor presentation differences to normalize.

These are contained risks because the BLE manager, parser, and main content view remain unchanged.

## Implementation Notes

- Keep the change narrow and reviewable.
- Do not change Bluetooth entitlements or privacy strings.
- Do not alter BLE packet parsing logic for this task.
- Preserve current logging; no additional hardware assumptions are needed.
