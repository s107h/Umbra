# Manual Hardware Test Steps

Use these steps with a physical Umbra nearby. The current app now scans, connects, starts the notification stream, logs raw payloads, and attempts weight parsing for the captured `EF DD 0C 08 05` packet family.

## Before launching the app

1. Turn on the Umbra.
2. Confirm the scale's Bluetooth setting is enabled.
3. Make sure the scale is not currently connected to the Acaia mobile app or another device.
4. On macOS, confirm Bluetooth is enabled.

## In the app

1. Launch `UmbraScale`.
2. Confirm the status moves to `Bluetooth ready` after CoreBluetooth finishes initializing.
3. Confirm the menu bar only shows the scale glyph and clicking it while disconnected opens a small popup with a large `Disconnected` label plus a gear button.
4. Click the gear and confirm a centered HUD opens in expanded mode with controls, the device list, and the debug log.
5. Click `Scan`.
6. Verify a likely Acaia peripheral appears in the candidate list.
7. Confirm the debug log records the candidate name, RSSI, and advertised local name.
8. Click `Connect` for the Umbra candidate.
9. Verify the app activates and a centered compact HUD appears automatically.
10. Verify the status transitions through connecting and service discovery.
11. Confirm the debug log lists every discovered service UUID.
12. Confirm the debug log lists every characteristic UUID and its properties.
13. If a notify-capable characteristic is found, confirm the log records notification subscription state.
14. Confirm the log records notify subscription state, outgoing identify and notification-request packets, and heartbeat writes.
15. If the empty scale shows a non-zero baseline such as `0.8 g`, expand the HUD and click `Zero Display` to calibrate the UI to the current reading.
16. Put any small object on the Umbra.
17. Confirm the log shows `RX` lines for the `0000FE42-...` notify characteristic.
18. Confirm at least some `RX` lines with `EF DD 0C 08 05` are followed by `Parsed weight reading ... g`.
19. Confirm the compact HUD reflects the live reading and the expanded HUD still shows `Weight` plus `Raw Weight`.
20. Drag the HUD and verify it remains movable.
21. Toggle the gear and confirm the HUD expands and collapses in place.
22. Disconnect or power off the scale and confirm the HUD dismisses automatically while the disconnected popup remains available from the menu bar glyph.

## Fellow Kettle Wi-Fi Validation

Use these steps with a real Fellow Stagg EKG Pro Wi-Fi on the same network as the Mac. Keep the Umbra powered on nearby for the final mixed-path check so the BLE scale flow can be verified alongside the kettle flow.

1. Launch `UmbraScale` and open the expanded HUD from the menu bar.
2. Confirm the scale section still renders normally before touching the Fellow controls.
3. Expand the `Debug Log` disclosure and leave it open for the remaining Fellow checks.
4. In the `Fellow Kettle` section, inspect the current host field and status first. If the intended kettle host is already saved and the status shows `Configured host <host>`, keep it; otherwise replace any saved value with the kettle IP address or hostname you want to test, then click `Save`.
5. Confirm the host field keeps the saved value and the status shows `Configured host <host>`, then `Polling <host>...`, and then `Connected to <host>` once the first response returns.
6. Within 5 seconds, verify `Current Temp` and `Target Temp` populate with non-empty values that match the kettle's current screen or known idle state.
7. Confirm the Fellow debug log records the saved host, the request URL for the `state` poll, the HTTP status, and the raw response body without affecting the Umbra status or weight display.
8. Enter a new target temperature such as `96.0`, then click `Set`.
9. Confirm the HUD log shows a `setsetting settempr` request followed by `setstate S_Heat`.
10. Verify the kettle itself begins heating, the status stays connected, and the displayed target temperature updates to the requested value or the nearest value accepted by the kettle firmware.
11. Watch the next few polling cycles and confirm `Current Temp` trends upward while the Umbra section continues updating normally if the scale is connected.
12. Click `Heat Off`.
13. Confirm the log shows the heat-off command, the kettle exits heating mode, `Heat State` changes to the off-equivalent result, and the status returns to `Connected to <host>` after the next successful poll.
14. Replace the saved host with an invalid value such as `http://invalid.local` or a non-routable IP, then click `Save`.
15. Confirm the Fellow section reports a polling or connection error and the debug log captures the failed request details.
16. While the Fellow section is in the error state, verify the Umbra BLE path still works: the scale can stay connected, live weight continues updating, and the HUD remains responsive.
17. Restore the valid kettle host if additional hardware testing is needed.

## Current limits

- Only the captured 13-byte Umbra weight packet family is parsed right now.
- Other packet types are still logged as raw hex and reported as unhandled.
- BLE tare is still not implemented. `Zero Display` is an app-side calibration only.
