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
3. In the `Fellow Kettle` section, expand that section's `Debug Log` disclosure and leave it open for the remaining Fellow checks.
4. If no kettle host is saved, confirm the Fellow section shows `Discovery: Searching` within a moment of launch.
5. If the kettle advertises over mDNS and is the only matching candidate, confirm the app auto-adopts it, shows `Configured Host` with the discovered HTTP host, then enters `Polling <host>...`, and then reaches `Connected to <host>`.
6. If mDNS does not find the kettle, use the host field as the fallback path: enter the kettle IP address or hostname you want to test, then click `Save`.
7. Within 5 seconds of either auto-adoption or manual save, verify `Current Temp` and `Target Temp` populate with non-empty values that match the kettle's current screen or known idle state.
8. Confirm the Fellow debug log records the resolved or saved host, the request URL for the `state` poll, the `prtsettings` request, the HTTP status, and the raw response bodies without affecting the Umbra status or weight display.
9. Enter a new target temperature such as `96.0`, then click `Set`.
10. Confirm the HUD log shows a `setsetting settempr` request followed by `setstate S_Heat`.
11. Verify the kettle itself begins heating, the status stays connected, and the displayed target temperature updates to the requested value or the nearest value accepted by the kettle firmware.
12. Change the `Units` picker to `Fahrenheit`, then click `Set Units`.
13. Confirm the kettle reflects the new units mode and the Fellow section updates the `Units` row accordingly.
14. Change the `Hold` picker to `45 min`, then click `Set Hold`.
15. Confirm the kettle reflects the new hold duration and the Fellow section updates the `Hold` row accordingly.
16. Click `Heat Off`.
17. Confirm the log shows the heat-off command, then a follow-up refresh or successful poll reflects the off-equivalent `Heat State` while the status settles back on `Connected to <host>` after the request path completes.
18. Replace the saved host with an invalid value such as `http://invalid.local` or a non-routable IP, then click `Save`.
19. Confirm the Fellow section reports a polling or connection error and the debug log captures the failed request details.
20. While the Fellow section is in the error state, verify the Umbra BLE path still works: the scale can stay connected, live weight continues updating, and the HUD remains responsive.
21. Restore the valid kettle host if additional hardware testing is needed.

## Fellow Kettle BLE Research Validation

1. Launch `UmbraScale` and open the expanded HUD.
2. Leave the normal `Fellow Kettle` Wi-Fi controls untouched and expand `BLE Research`.
3. Click `Scan BLE` and confirm at least one likely Fellow candidate appears with name and RSSI.
4. Select the intended kettle and confirm the research status moves through connecting, service discovery, characteristic discovery, and capture.
5. Confirm the BLE log records every discovered service UUID and characteristic UUID plus properties.
6. Confirm read-capable characteristics produce `read` log lines and notify or indicate characteristics produce payload log lines.
7. If any payload contains a hostname, `.local` name, or IPv4-like value, copy the BLE log and record the exact characteristic UUID that produced it.
8. Compare the candidate value against the known working Wi-Fi host or IP and test it manually with the existing HTTP kettle path.
9. Count the research slice as successful only if the BLE-derived value reproducibly works with `/cli?cmd=state`.
10. If no reproducible endpoint appears, record the capture as evidence for a bounded failure conclusion rather than extending the slice with speculative writes.

## Current limits

- Only the captured 13-byte Umbra weight packet family is parsed right now.
- Other packet types are still logged as raw hex and reported as unhandled.
- BLE tare is still not implemented. `Zero Display` is an app-side calibration only.
- Fellow BLE-assisted endpoint recovery is not part of the current kettle auto-discovery path yet; the live path is mDNS first, with manual host entry as fallback.
