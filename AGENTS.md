# AGENTS.md

Before making code changes, read:

- docs/acaia_umbra_macos_app_codex_plan.md

Project goal:
Build a native macOS SwiftUI app that connects to an Acaia Umbra scale over Bluetooth Low Energy and displays live weight readings.

Important constraints:
- Use SwiftUI and CoreBluetooth.
- Build incrementally by phases from the plan.
- Do not assume the Umbra protocol fully matches Lunar/Pearl until BLE discovery logs confirm it.
- Keep BLE packet parsing isolated in a testable parser type.
- Add logging for discovered services, characteristics, notification payloads, and connection state.
- Do not remove Bluetooth entitlement or privacy usage strings.
- Prefer small, reviewable commits.

Validation:
- Run available Swift tests after parser changes.
- Run xcodebuild when possible.
- For hardware behavior, add clear manual test steps because live BLE testing requires the physical scale.