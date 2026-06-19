# Fellow Kettle Discovery and Settings Design

## Summary

Refactor and extend the existing Fellow kettle support in UmbraScale by adding:

- automatic kettle discovery
- BLE-assisted Wi-Fi endpoint resolution
- automatic adoption of a confidently resolved kettle
- richer kettle settings control focused on units and hold duration

This work should build on the current Fellow HTTP CLI integration rather than replacing it. The existing Umbra BLE scale path and HUD behavior must remain stable.

## Goals

- Preserve the current split between Umbra BLE scale support and Fellow kettle support.
- Make kettle onboarding default to discovery instead of manual host entry.
- Automatically adopt a discovered kettle when the result is confident and usable.
- Extend kettle controls beyond heat on/off and target temperature.
- Keep the UI centered on the existing expanded HUD/menu bar experience.

## Non-Goals

- Home Assistant integration or entity modeling.
- Schedule editing or clock management.
- Raw power-user CLI tooling as part of the main user flow.
- Diagnostics bundle features beyond the existing debug logging pattern.
- Buzzer/chime controls.
- Brew presets in this slice.
- Reworking the Umbra scale BLE subsystem.

## Current State

The repo already includes a first-slice Fellow subsystem:

- `FellowKettleManager` for app-facing polling, commands, and logging
- `FellowSupport` types for request building and response parsing
- `FellowKettleSection` in the expanded HUD
- tests for parser and manager behavior
- manual host-based onboarding

This design extends that subsystem rather than replacing it.

## External Source Constraints

The referenced `bramboe/stagg-ekg-plus-ha` repository confirms that the target device is the Fellow Stagg EKG Pro Wi-Fi kettle and that control happens through the local unauthenticated HTTP CLI at `/cli`. That repo also demonstrates that:

- control is Wi-Fi based, not BLE based, for normal operations
- BLE can be useful for discovery
- mDNS may provide an HTTP discovery path when available
- units, hold, and other settings are exposed through CLI commands

UmbraScale should reuse those protocol learnings, but not bring in any Home Assistant concepts or structure.

## Recommended Approach

Use an incremental subsystem expansion.

Keep the current architecture where `FellowKettleManager` is the single app-facing kettle controller and add two bounded capabilities around it:

1. a separate discovery subsystem for mDNS plus BLE-assisted resolution
2. an expanded HTTP CLI command surface for kettle settings

Do not introduce a new unified device coordinator above both scale and kettle in this slice. Do not merge kettle BLE logic into `AcaiaScaleManager`.

## Architecture

### Existing boundaries to preserve

- `AcaiaScaleManager` remains responsible only for Umbra BLE scanning, connection, handshake, notifications, and weight updates.
- `FellowKettleManager` remains responsible only for kettle host state, polling, command execution, snapshot publication, and kettle-specific logs.
- HUD and menu bar views continue consuming app-facing observable state without embedding protocol logic.

### New subsystem: FellowKettleDiscoveryManager

Add a dedicated discovery manager with a narrow purpose:

- start and stop kettle discovery
- combine results from mDNS and BLE-assisted resolution
- assign confidence to candidate endpoints
- auto-adopt a kettle when a single usable result is strong enough
- publish discovery status for UI and logging

This manager should be isolated from the Umbra scale BLE path. If BLE is used for kettle discovery, it must use a separate BLE boundary from the Umbra scale manager so scale behavior and parser logging are not destabilized.

### Expanded Fellow HTTP command surface

Extend the existing Fellow support layer with request-building and parsing support for:

- temperature unit changes
- hold duration changes

The support layer should stay narrow and testable. Request construction belongs in `FellowSupport`; command orchestration and polling behavior belong in `FellowKettleManager`.

## Discovery Design

### Discovery sources

The first implementation should use both of these sources:

1. mDNS or Bonjour discovery for likely local HTTP services
2. BLE-assisted discovery to identify a likely Fellow or Stagg kettle and attempt Wi-Fi endpoint resolution

Both sources should feed one combined discovery model rather than separate user workflows.

### Discovery behavior

When there is no active configured kettle, discovery should start automatically.

Expected flow:

1. Start mDNS discovery.
2. Start BLE-assisted discovery.
3. If one source yields a high-confidence usable HTTP endpoint, auto-adopt it.
4. Once adopted, start normal kettle polling through `FellowKettleManager`.

Discovery is primarily an onboarding and recovery tool, not a replacement for steady-state polling.

### Auto-adoption policy

The user explicitly wants aggressive auto-connect behavior, but the implementation must still avoid bad automatic switches.

Auto-adopt only when:

- exactly one candidate has a usable HTTP base URL
- the candidate meets the app’s confidence threshold
- no existing known-good active kettle should be preserved instead

Do not auto-adopt when:

- multiple candidates conflict
- BLE finds a kettle but endpoint resolution is incomplete
- the result would overwrite an active known-good kettle without a clear replacement action

Once a kettle is auto-adopted, the app should not thrash between candidates. A later candidate should only replace the active kettle through an explicit reset or a clearly defined recovery policy.

### BLE-assisted resolution policy

If discovery finds a kettle over BLE without a usable Wi-Fi endpoint, the app should attempt a BLE-assisted resolution flow. If that resolution succeeds, the app should auto-adopt the kettle.

If BLE identification succeeds but resolution fails, the app should:

- keep the partial result as diagnostic state
- continue discovery
- avoid overwriting any known-good configured host

## Kettle Settings Design

### In-scope controls

This slice should prioritize:

- temperature units
- hold duration
- existing target temperature and heat controls with better integration into discovery-backed onboarding

### Out-of-scope controls

The following should stay out of this design:

- schedule time and mode editing
- brew presets
- clock adjustment or sync
- altitude
- pre-boil
- buzzer or chime control
- firmware and advanced diagnostics surfaces

These are valid follow-up issues, but they are independent enough that they should not be bundled into this refactor.

### Command model

`FellowKettleManager` should remain the single UI-facing action surface.

Expected actions include:

- refresh current state
- set heat enabled
- set target temperature
- set units
- set hold duration

Each action should:

- log the outgoing command
- execute through the Fellow HTTP request layer
- refresh state or confirm success through the next poll
- preserve the last known good snapshot when failures occur

## UI Design

Keep the current one-section Fellow surface inside the expanded HUD and menu bar rather than creating separate windows or modal flows.

The section should be reorganized into clear groups:

- discovery and active-kettle status
- current and target temperatures
- heat state and core actions
- settings controls for units and hold
- debug controls and logs

Manual host entry can remain as a fallback, but discovery should become the default path. The UI should communicate when a host was automatically adopted versus manually entered.

## Data Flow

Steady-state kettle behavior should follow this sequence:

1. App launches and loads any saved kettle identity or host.
2. If there is no usable active kettle, discovery begins automatically.
3. Discovery combines mDNS and BLE-assisted resolution results.
4. If a confident endpoint is resolved, the app auto-adopts it.
5. `FellowKettleManager` begins normal polling using the adopted host.
6. User actions for heat, target, units, or hold execute through `FellowKettleManager`.
7. UI reflects confirmed state and preserves the last known good snapshot through transient errors.

This keeps discovery separate from steady-state control while preserving a single app-facing kettle model.

## Error Handling

The system must be fail-soft.

- Discovery failures must not affect Umbra scale BLE behavior.
- Discovery failures must not break polling against a known-good kettle host.
- mDNS and BLE discovery should log their own events, retries, and rejection reasons.
- Partial BLE sightings should remain diagnostic unless endpoint resolution succeeds.
- Settings actions should not update durable UI state unless the command is acknowledged or a follow-up poll confirms the change.

If multiple discovery candidates are present, the app should surface conflict rather than silently switching.

## Testing Strategy

### Automated tests

Add or extend tests for:

- discovery candidate confidence and adoption rules
- conflict handling when multiple candidates appear
- preservation of the last known snapshot through discovery or command failures
- request building for unit and hold commands
- parsing changes required by the richer settings surface
- manager behavior around command-in-flight and recovery transitions

Run:

- focused Fellow tests
- full `swift test`
- `xcodebuild -project UmbraScale.xcodeproj -scheme UmbraScale -destination 'platform=macOS' build`

### Manual validation

Because live discovery and kettle control depend on real hardware and network conditions, document manual checks for:

1. clean launch with no saved kettle and successful automatic discovery
2. BLE-assisted endpoint resolution when mDNS is absent
3. auto-adoption into active polling
4. changing units and verifying the kettle reflects the change
5. changing hold duration and verifying the kettle reflects the change
6. preserving scale BLE stability while kettle discovery and polling are active
7. handling unreachable or ambiguous discovery results without destabilizing the active kettle

## Risks And Mitigations

### Risk: discovery destabilizes scale BLE behavior

Mitigation:

- keep kettle BLE-assisted discovery outside `AcaiaScaleManager`
- isolate BLE responsibilities behind a dedicated kettle discovery boundary

### Risk: auto-adoption picks the wrong kettle

Mitigation:

- require a usable endpoint and a confidence threshold
- refuse silent switching when multiple candidates conflict
- avoid replacing a known-good active kettle casually

### Risk: settings commands behave differently than expected

Mitigation:

- keep request building isolated and testable
- verify command semantics against documented CLI behavior and hardware tests

## Implementation Slice

This design is intended to support one implementation plan covering:

1. discovery manager and candidate model
2. mDNS plus BLE-assisted endpoint resolution integration
3. auto-adoption rules and persistence updates
4. units and hold controls in the Fellow command surface
5. HUD and menu bar updates for discovery-aware kettle status
6. tests and manual verification updates

## Open Decisions Resolved By This Design

- Primary kettle expansion focus: settings control, not schedules or diagnostics
- Discovery sources: both mDNS and BLE-assisted resolution
- Onboarding behavior: aggressive auto-adopt when confidence is high
- BLE-only partial discovery behavior: attempt endpoint resolution and adopt only on success

## Follow-Up Work

Likely follow-up issues after this slice:

- brew presets
- schedule and clock editing
- diagnostics and firmware surfaces
- buzzer or notification controls
- altitude and advanced calibration-related settings
