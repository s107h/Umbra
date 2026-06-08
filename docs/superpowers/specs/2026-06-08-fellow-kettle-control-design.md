# Fellow Kettle Control Design

Date: 2026-06-08
Repo: `/Users/sid/Developer/UmbraScale`

## Goal

Add first-slice control of a Fellow Stagg EKG Pro kettle to the app using the kettle's local Wi-Fi HTTP CLI, while keeping the existing Acaia Umbra BLE scale path isolated and stable.

This slice should support:

- Configuring a kettle host or IP address.
- Polling kettle state from the local network.
- Displaying current temperature, target temperature, and heating status.
- Turning heating on and off.
- Setting a target temperature.
- Logging request, response, and error details for local diagnostics.

This slice should not depend on BLE reverse engineering for the kettle.

## Context

The current repo already has a clear boundary around the Umbra BLE integration:

- `AcaiaScaleManager` owns CoreBluetooth lifecycle for the scale.
- `AcaiaProtocol` and `AcaiaWeightParser` isolate scale protocol behavior and parsing.
- The HUD renders device-specific sections and debug logs.

The `fellow-ekg-pro-discovery` branch adds a BLE discovery panel for likely Fellow devices, but it does not yet implement a safe or verified control path.

External references reviewed during brainstorming point to a different primary integration path:

- `fabiankirchen/staggassistant` controls the Fellow Stagg EKG Pro over the kettle's local HTTP CLI.
- `Willmac16/homebridge-kettle` `ekg-pro-cli` branch also uses the local HTTP CLI, including `state`, `setstate`, and `setsetting settempr`.

Based on that evidence, Wi-Fi CLI control is the correct first integration target. BLE discovery should remain optional research and should not block the first useful kettle slice.

## Non-Goals

- BLE control of the Fellow kettle.
- Automatic kettle discovery on the local network.
- Exhaustive support for all known CLI commands.
- Scheduling, chime, altitude, language, or dial/button emulation.
- Refactoring the Acaia scale stack into a shared cross-device transport abstraction.

## Recommended Approach

Add a parallel Fellow subsystem rather than extending the Acaia subsystem.

The app should gain a dedicated kettle manager and a small HTTP-based protocol layer:

- `FellowKettleManager`: app-facing `ObservableObject` for status, latest kettle state, polling, and user actions.
- `FellowKettleCLIClient`: narrow HTTP client for issuing CLI commands and returning raw text.
- `FellowKettleParser`: pure parsing helpers for CLI output such as `state` and optional follow-on endpoints.

This approach is preferred because it:

- Preserves the existing BLE scale boundaries.
- Matches the discovered real-world control path for the EKG Pro.
- Keeps protocol parsing isolated and testable.
- Avoids premature abstraction across unrelated device transports.

## Architecture

### FellowKettleManager

Responsibilities:

- Store configured kettle endpoint.
- Own polling lifecycle and published state.
- Trigger user actions such as heat on, heat off, and set target temperature.
- Convert parser output into SwiftUI-friendly view state.
- Maintain kettle-specific debug logging.

Published state should include:

- connection or status text
- configured host
- current temperature in Celsius
- target temperature in Celsius
- heating mode
- last update time
- last error text

This manager must be independent from `AcaiaScaleManager`. Failures in kettle polling or commands must not affect scale scanning, connecting, or streaming.

### FellowKettleCLIClient

Responsibilities:

- Build `/cli?cmd=...` requests from a configured base URL.
- Encode command tokens correctly for HTTP queries.
- Apply short request timeouts.
- Return raw response text to the manager or parser.
- Surface network errors cleanly.

The client should not own app state or parsing logic.

### FellowKettleParser

Responsibilities:

- Parse `state` output into a normalized kettle state model.
- Extract current temperature, target temperature, and mode from representative CLI output.
- Handle malformed or partial responses without crashing.

This parser should be a pure type with focused unit tests, similar in spirit to `AcaiaWeightParser`.

### UI Integration

Add a dedicated Fellow section to the existing HUD rather than merging kettle controls into the scale section.

The section should show:

- configured kettle host
- current status
- current temperature
- target temperature
- heat on or off controls
- target temperature control
- debug log disclosure

This keeps the product model understandable: one scale section, one kettle section, each backed by its own manager.

## Data Flow

### Configuration

For this first slice, the kettle should be configured by host or IP address entered by the user. The app should treat the kettle as a known local endpoint rather than trying to discover it automatically.

### Read Path

Primary polling command:

- `state`

Optional secondary commands:

- `prtsettings` if needed to resolve units or additional metadata
- `prtclock` later, if clock display becomes a product requirement

The manager should poll the minimum useful surface first. The design should not assume that every secondary CLI endpoint is needed for MVP.

### Write Path

Supported commands for this slice:

- `setstate S_Heat`
- `setstate S_Off`
- `setsetting settempr <fahrenheit>`

After setting target temperature, the manager may follow with `setstate S_Heat` to ensure active heating begins, matching the behavior observed in existing community integrations.

### Unit Conversion

The UI should operate in Celsius for the first slice. The command layer should convert Celsius target values to the Fahrenheit-based command format expected by the kettle CLI when required.

### Logging

The kettle subsystem should log:

- outgoing command name
- resolved request URL excluding sensitive surprises in future fields
- response summaries
- parse results
- timeout or network failures

Logging should be user-visible in the HUD for local diagnosis.

## State Model

Add a kettle-focused state model distinct from `AcaiaScaleState`.

Recommended normalized states:

- idle
- unconfigured
- connecting
- polling
- ready
- commandInFlight
- error

The exact enum names can be refined during implementation, but the model should separate:

- setup problems such as missing host
- connectivity problems such as timeout
- normal ready state with last known kettle values
- transient write activity

## Error Handling

The kettle path must be fail-soft:

- If the kettle is unreachable, show an error and retry on the next poll.
- If a response is malformed, preserve the last valid reading when reasonable and log the parse failure.
- If a write command fails, show the failure immediately and keep the rest of the app responsive.
- If firmware differences affect command support, log the raw response and avoid assuming success.

The scale BLE path must continue operating normally even when the kettle is offline or misconfigured.

## Testing Strategy

### Automated Tests

Add focused tests for:

- parsing representative `state` outputs
- parsing `S_Off`, `S_Heat`, and other expected heating states
- malformed or partial response handling
- Celsius-to-Fahrenheit conversion
- command encoding for CLI requests

Avoid heavy end-to-end manager tests unless they add clear value. Prefer parser and client-level tests with deterministic fixtures.

### Manual Validation

Document and verify:

1. Configure a reachable kettle host.
2. Confirm current and target temperature appear in the HUD.
3. Change the target temperature and confirm the kettle responds.
4. Turn heat on and off from the app.
5. Disconnect the kettle from the network or use a bad host and confirm the app surfaces a clear error without affecting the scale.

Because hardware validation requires a real kettle on the local network, the implementation should include explicit manual test steps in repo docs.

## Phasing

Recommended implementation order:

1. Add Fellow models, CLI client, and parser with tests.
2. Add `FellowKettleManager` with polling and command actions.
3. Add basic host configuration and HUD rendering.
4. Add manual validation steps and logging refinements.
5. Keep BLE discovery as a separate diagnostic or research path, not part of the MVP control flow.

## Tradeoff Summary

Chosen direction:

- Separate Fellow Wi-Fi control subsystem.

Rejected for this slice:

- Shared generic transport abstraction now: too much refactor cost for limited immediate benefit.
- Merging kettle logic into the scale manager: poor boundaries and higher long-term coupling.
- BLE-first control: not supported by the strongest available integration evidence and would delay useful functionality.

## Open Decisions For Planning

These should be resolved in the implementation plan, not by widening the design scope:

- Where the kettle host should be persisted in app settings.
- Whether the first target temperature control is a text field, stepper, or slider.
- Default poll interval and backoff behavior.
- Whether to keep the BLE discovery panel compiled in alongside Wi-Fi control during the first implementation slice.
