# Manual BLE Test Steps

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

## Fellow Stagg EKG Pro Wi-Fi Validation

Use these steps with a real Fellow Stagg EKG Pro Wi-Fi on the same network as the Mac. Keep the Umbra powered on nearby for the final mixed-path check so the BLE scale flow can be verified alongside the kettle flow.

1. Launch `UmbraScale` and open the expanded HUD from the menu bar.
2. Confirm the scale section still renders normally before touching the Fellow controls.
3. In the `Fellow Stagg EKG Pro` section, enter the kettle IP address or hostname, then click `Save Host`.
4. Confirm the host field keeps the saved value and the status changes from `Enter kettle host` to `Polling ...` and then to a connected or ready state once the first response returns.
5. Within 5 seconds, verify `Current Temp` and `Target Temp` populate with non-empty values that match the kettle's current screen or known idle state.
6. Confirm the Fellow debug log records the saved host, the outgoing `state` request, and the parsed response without affecting the Umbra status or weight display.
7. Enter a new target temperature such as `96.0`, then click `Set`.
8. Confirm the HUD log shows a `setsetting settempr` request followed by `setstate S_Heat`.
9. Verify the kettle itself begins heating, the status stays connected, and the displayed target temperature updates to the requested value or the nearest value accepted by the kettle firmware.
10. Watch the next few polling cycles and confirm `Current Temp` trends upward while the Umbra section continues updating normally if the scale is connected.
11. Click `Heat Off`.
12. Confirm the log shows the heat-off command, the kettle exits heating mode, and the status returns to an idle or off-equivalent connected state on the next poll.
13. Replace the saved host with an invalid value such as `http://invalid.local` or a non-routable IP, then click `Save Host`.
14. Confirm the Fellow section reports a polling or connection error and the debug log captures the failed request.
15. While the Fellow section is in the error state, verify the Umbra BLE path still works: the scale can stay connected, live weight continues updating, and the HUD remains responsive.
16. Restore the valid kettle host if additional hardware testing is needed.

## Current limits

- Only the captured 13-byte Umbra weight packet family is parsed right now.
- Other packet types are still logged as raw hex and reported as unhandled.
- BLE tare is still not implemented. `Zero Display` is an app-side calibration only.
