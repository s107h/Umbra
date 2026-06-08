# Codex Plan: macOS BLE App for Acaia Umbra Scale

## Goal

Build a native macOS SwiftUI app that connects to an **Acaia Umbra** scale over Bluetooth Low Energy and displays the live scale reading in grams.

The app should start with a reliable MVP:

- Scan for nearby Acaia/Umbra BLE devices.
- Connect to the selected scale.
- Discover BLE services and characteristics.
- Subscribe to scale notifications.
- Perform the Acaia-style handshake.
- Stream live weight readings.
- Display connection state, latest weight, and raw BLE debug logs.
- Support a basic **Tare** button if the command works on Umbra.
- Be robust when the Umbra BLE protocol differs from older Acaia Lunar/Pearl implementations.

## Important assumptions and risks

The Acaia Umbra appears to be a display-free, Bluetooth-enabled scale intended to work with Acaia apps and other Acaia displays. Acaia’s product page says the Umbra connects with a smartphone app and uses real-time communication / Magic Relay with compatible devices.

However, Acaia’s public SDK repositories currently document support for Pearl, Lunar, Pearl S, Cinco, and Pyxis, not Umbra specifically. The app therefore must treat the existing Acaia BLE protocol as a **probable starting point**, not as a guaranteed match.

Community references for Acaia scales indicate a common BLE setup using:

```text
New-style write characteristic:
49535343-8841-43F4-A8D4-ECBE34729BB3

New-style notify/read characteristic:
49535343-1E4D-4BD9-BA61-23C647249616

Old-style read/write characteristic:
2A80
```

Community references also suggest this initialization order:

1. Connect.
2. Discover services/characteristics.
3. Subscribe to notifications.
4. Send identify/handshake packet.
5. Send notification request packet.
6. Start a heartbeat loop roughly every 2.75 to 3 seconds.
7. Parse weight packets from notification data.

Because Umbra support is not officially documented in the public SDKs, the MVP must include raw BLE logging so the protocol can be adjusted after a real capture.

## Source notes for Codex

Use these as context, not as copy-paste dependencies.

- Acaia Umbra product page: https://acaia.co/products/umbra
- Acaia iOS SDK repository: https://github.com/acaia/acaia_sdk_ios
- Acaia Android SDK repository: https://github.com/acaia/acaia_sdk_android
- AcaiaArduinoBLE community library: https://github.com/tatemazer/AcaiaArduinoBLE
- AcaiaArduinoBLE header with known UUID constants: https://github.com/tatemazer/AcaiaArduinoBLE/blob/main/AcaiaArduinoBLE.h
- `acaia-lunar-ble` package notes on write/notify UUIDs and startup order: https://pypi.org/project/acaia-lunar-ble/
- Apple Core Bluetooth docs: https://developer.apple.com/documentation/corebluetooth
- Apple macOS Bluetooth entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.bluetooth
- Acaia Bluetooth setting help article: https://help.acaia.co/hc/en-us/articles/360035376551-Bluetooth-Setting

Licensing caution: do not copy implementation code from AGPL projects into this app. Use public protocol behavior and write original Swift code. MIT-licensed sources may be referenced if license requirements are preserved, but prefer original implementation.

## Target platform

- Native macOS app.
- Swift.
- SwiftUI UI.
- CoreBluetooth for BLE.
- No Catalyst.
- No official Acaia iOS SDK dependency, because the target is macOS and Umbra is not listed in the public SDK support matrix.

## MVP user experience

Single-window app:

```text
Acaia Umbra Scale

Status: Bluetooth Ready / Scanning / Connecting / Connected / Disconnected / Error
Device: [name or "None"]
Weight: 0.0 g

[Scan] [Disconnect] [Tare]

Debug:
- discovered peripheral name, identifier, RSSI
- discovered services
- discovered characteristics
- notify subscription result
- outgoing command hex
- incoming notify packet hex
- parsed packet result or parser miss reason
```

Keep the first UI practical rather than fancy. The most important feature is confirming the BLE protocol.

## Project structure

Create these files:

```text
UmbraScaleApp/
  UmbraScaleApp.swift
  ContentView.swift

  Bluetooth/
    AcaiaScaleManager.swift
    AcaiaScaleState.swift
    AcaiaBLEUUIDs.swift
    AcaiaProtocol.swift
    BLELogger.swift

  Models/
    ScaleReading.swift
    DiscoveredScale.swift

  Tests/
    AcaiaProtocolTests.swift
```

If using an existing Xcode project, add the same logical files and groups.

## App entitlements and Info.plist

### Info.plist

Add a Bluetooth usage description:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app connects to your Acaia scale over Bluetooth to display live weight readings.</string>
```

### Entitlements

For a sandboxed macOS app, enable:

```text
Signing & Capabilities
  App Sandbox
    Hardware
      Bluetooth
```

This should add:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.bluetooth</key>
<true/>
```

## State model

Create `AcaiaScaleState.swift`:

```swift
enum AcaiaScaleState: Equatable {
    case idle
    case bluetoothUnavailable(String)
    case bluetoothReady
    case scanning
    case discovered(name: String)
    case connecting(name: String)
    case discoveringServices(name: String)
    case subscribing(name: String)
    case handshaking(name: String)
    case streaming(name: String)
    case disconnected
    case error(String)
}
```

Expose user-facing text through a computed property:

```swift
extension AcaiaScaleState {
    var displayText: String {
        switch self {
        case .idle: return "Idle"
        case .bluetoothUnavailable(let reason): return "Bluetooth unavailable: \(reason)"
        case .bluetoothReady: return "Bluetooth ready"
        case .scanning: return "Scanning..."
        case .discovered(let name): return "Found \(name)"
        case .connecting(let name): return "Connecting to \(name)..."
        case .discoveringServices(let name): return "Discovering services for \(name)..."
        case .subscribing(let name): return "Subscribing to \(name)..."
        case .handshaking(let name): return "Starting scale stream for \(name)..."
        case .streaming(let name): return "Connected to \(name)"
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error: \(message)"
        }
    }
}
```

## Models

Create `ScaleReading.swift`:

```swift
import Foundation

struct ScaleReading: Equatable {
    var grams: Double
    var isStable: Bool?
    var timestamp: Date

    static let zero = ScaleReading(grams: 0, isStable: nil, timestamp: Date())
}
```

Create `DiscoveredScale.swift`:

```swift
import CoreBluetooth
import Foundation

struct DiscoveredScale: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int

    init(peripheral: CBPeripheral, name: String, rssi: Int) {
        self.id = peripheral.identifier
        self.name = name
        self.rssi = rssi
    }
}
```

## BLE UUID constants

Create `AcaiaBLEUUIDs.swift`:

```swift
import CoreBluetooth

enum AcaiaBLEUUIDs {
    static let oldReadWrite = CBUUID(string: "2A80")

    static let newWrite = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    static let newNotify = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")

    // Common transparent UART service UUID used by modules that expose the above characteristics.
    // Do not rely on this for the first scan; discover all services initially.
    static let transparentUARTService = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
}
```

## BLE logger

Create `BLELogger.swift`:

```swift
import Foundation

@MainActor
final class BLELogger: ObservableObject {
    @Published private(set) var lines: [String] = []

    func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        lines.append("[\(timestamp)] \(message)")

        if lines.count > 500 {
            lines.removeFirst(lines.count - 500)
        }
    }

    func clear() {
        lines.removeAll()
    }
}
```

Add a hex helper:

```swift
extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

extension Array where Element == UInt8 {
    var data: Data { Data(self) }

    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
```

## Protocol implementation

Create `AcaiaProtocol.swift`.

This file should contain:

1. Command byte arrays.
2. Packet parser.
3. Checksum helpers if needed.
4. Unit tests for parser behavior.

### Commands

Start with community-derived command packets. Mark these as provisional until tested against Umbra.

```swift
import Foundation

enum AcaiaProtocol {
    // Community-derived. Validate with Umbra.
    static let identify: [UInt8] = [
        0xEF, 0xDD, 0x0B,
        0x30, 0x31, 0x32, 0x33, 0x34,
        0x35, 0x36, 0x37, 0x38, 0x39,
        0x30, 0x31, 0x32, 0x33, 0x34,
        0x9A, 0x6D
    ]

    // Community-derived request for weight/battery/timer/key/settings notifications.
    // Validate with Umbra.
    static let notificationRequest: [UInt8] = [
        0xEF, 0xDD, 0x0C, 0x09,
        0x00, 0x01, 0x01, 0x02,
        0x02, 0x05, 0x03, 0x04,
        0x15, 0x06
    ]

    // Community-derived heartbeat.
    // Validate with Umbra.
    static let heartbeat: [UInt8] = [
        0xEF, 0xDD, 0x00, 0x02, 0x00, 0x02, 0x00
    ]

    // Community-derived tare command. Validate with Umbra.
    static let tare: [UInt8] = [
        0xEF, 0xDD, 0x04, 0x00, 0x00, 0x00
    ]
}
```

### Packet parser

Implement a parser that accepts raw `Data` and returns a `ScaleReading?`.

Start with provisional parsing for known Acaia-style packets:

```swift
extension AcaiaProtocol {
    static func parseWeightPacket(_ data: Data) -> ScaleReading? {
        let bytes = [UInt8](data)

        if let newReading = parseNewStyleWeightPacket(bytes) {
            return newReading
        }

        if let oldReading = parseOldStyleWeightPacket(bytes) {
            return oldReading
        }

        return nil
    }

    private static func parseNewStyleWeightPacket(_ bytes: [UInt8]) -> ScaleReading? {
        guard (bytes.count == 13 || bytes.count == 17) else { return nil }
        guard bytes.indices.contains(10) else { return nil }

        // Known Acaia community parser convention:
        // byte 4 == 0x05 appears to mark a weight event.
        guard bytes[4] == 0x05 else { return nil }

        let raw = UInt16(bytes[6]) << 8 | UInt16(bytes[5])
        let divisor = pow(10.0, Double(bytes[9]))
        guard divisor != 0 else { return nil }

        var grams = Double(raw) / divisor

        // Sign bit convention used by community parsers.
        if (bytes[10] & 0x02) != 0 {
            grams *= -1
        }

        // Stability bit is not guaranteed; keep nil until verified.
        return ScaleReading(grams: grams, isStable: nil, timestamp: Date())
    }

    private static func parseOldStyleWeightPacket(_ bytes: [UInt8]) -> ScaleReading? {
        guard (bytes.count == 10 || bytes.count == 14) else { return nil }
        guard bytes.indices.contains(7) else { return nil }

        let raw = UInt16(bytes[3]) << 8 | UInt16(bytes[2])
        let divisor = pow(10.0, Double(bytes[6]))
        guard divisor != 0 else { return nil }

        var grams = Double(raw) / divisor

        if (bytes[7] & 0x02) != 0 {
            grams *= -1
        }

        return ScaleReading(grams: grams, isStable: nil, timestamp: Date())
    }
}
```

Important: if real Umbra packets do not parse, do not force the parser. Log every packet and add new parsing based on captured data.

## Core Bluetooth manager

Create `AcaiaScaleManager.swift`.

Responsibilities:

- Own `CBCentralManager`.
- Scan for Acaia-like peripherals.
- Connect to the best discovered peripheral.
- Discover all services initially.
- Discover all characteristics for each service.
- Detect write and notify characteristics.
- Subscribe to notifications before sending handshake.
- Send identify and notification request.
- Start heartbeat timer.
- Parse incoming notifications.
- Publish weight/state/logs to SwiftUI.

Recommended public API:

```swift
@MainActor
final class AcaiaScaleManager: NSObject, ObservableObject {
    @Published private(set) var state: AcaiaScaleState = .idle
    @Published private(set) var reading: ScaleReading = .zero
    @Published private(set) var discoveredScales: [DiscoveredScale] = []
    @Published private(set) var connectedDeviceName: String?
    @Published var logger = BLELogger()

    var isConnected: Bool { ... }

    func startScanning()
    func stopScanning()
    func connect(to discoveredScale: DiscoveredScale)
    func disconnect()
    func tare()
}
```

Because `DiscoveredScale` only stores safe UI data, internally keep a dictionary:

```swift
private var peripheralsByID: [UUID: CBPeripheral] = [:]
```

### Manager internals

Use these properties:

```swift
private var central: CBCentralManager!
private var activePeripheral: CBPeripheral?
private var writeCharacteristic: CBCharacteristic?
private var notifyCharacteristic: CBCharacteristic?
private var heartbeatTimer: Timer?
private var handshakeSent = false
```

Initialize CoreBluetooth on the main queue for simpler SwiftUI updates:

```swift
central = CBCentralManager(delegate: self, queue: .main)
```

### Scanning strategy

Initial scan should not filter by service UUID, because Umbra service layout is not confirmed.

Use:

```swift
central.scanForPeripherals(
    withServices: nil,
    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

Filter names in `didDiscover`:

```swift
private func isLikelyAcaiaName(_ name: String) -> Bool {
    let upper = name.uppercased()
    return [
        "ACAIA",
        "UMBRA",
        "LUNAR",
        "PEARL",
        "PYXIS",
        "CINCO",
        "PROCH"
    ].contains { upper.contains($0) }
}
```

Be flexible: some BLE names may not be populated in `peripheral.name`; also inspect:

```swift
advertisementData[CBAdvertisementDataLocalNameKey] as? String
```

### Connection flow

On connect:

1. Stop scan.
2. Set peripheral delegate.
3. Clear stale characteristics.
4. Call `central.connect(peripheral)`.

On `didConnect`:

```swift
peripheral.discoverServices(nil)
```

On `didDiscoverServices`:

```swift
for service in services {
    logger.log("Service: \(service.uuid.uuidString)")
    peripheral.discoverCharacteristics(nil, for: service)
}
```

On `didDiscoverCharacteristicsFor`:

- Log every characteristic UUID and properties.
- Select write characteristic:
  - Prefer `AcaiaBLEUUIDs.newWrite`.
  - Fallback to `AcaiaBLEUUIDs.oldReadWrite` if it supports write.
- Select notify characteristic:
  - Prefer `AcaiaBLEUUIDs.newNotify`.
  - Fallback to `AcaiaBLEUUIDs.oldReadWrite` if it supports notify.
- Subscribe to notify characteristic with `setNotifyValue(true, for:)`.
- Do not send handshake until notification subscription callback confirms success.

On `didUpdateNotificationStateFor`:

- If notify is enabled and write characteristic exists, send handshake.

### Handshake

Implement:

```swift
private func sendHandshakeIfReady() {
    guard !handshakeSent else { return }
    guard activePeripheral != nil else { return }
    guard writeCharacteristic != nil else { return }
    guard notifyCharacteristic?.isNotifying == true else { return }

    handshakeSent = true
    state = .handshaking(name: connectedDeviceName ?? "scale")

    write(AcaiaProtocol.identify, label: "identify")
    write(AcaiaProtocol.notificationRequest, label: "notification request")
    startHeartbeat()
}
```

For writes:

```swift
private func write(_ bytes: [UInt8], label: String) {
    guard let peripheral = activePeripheral,
          let characteristic = writeCharacteristic else {
        logger.log("Cannot write \(label): missing peripheral or characteristic")
        return
    }

    let writeType: CBCharacteristicWriteType =
        characteristic.properties.contains(.writeWithoutResponse)
        ? .withoutResponse
        : .withResponse

    logger.log("TX \(label): \(bytes.hexString)")
    peripheral.writeValue(Data(bytes), for: characteristic, type: writeType)
}
```

Heartbeat:

```swift
private func startHeartbeat() {
    heartbeatTimer?.invalidate()
    heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.75, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.write(AcaiaProtocol.heartbeat, label: "heartbeat")
        }
    }
}
```

Stop heartbeat on disconnect or error.

### Notification handling

In `didUpdateValueFor`:

```swift
guard let data = characteristic.value else { return }
logger.log("RX \(characteristic.uuid.uuidString): \(data.hexString)")

if let reading = AcaiaProtocol.parseWeightPacket(data) {
    self.reading = reading
    self.state = .streaming(name: connectedDeviceName ?? "scale")
    logger.log(String(format: "Parsed weight: %.1f g", reading.grams))
} else {
    logger.log("Parser ignored packet")
}
```

### Disconnect handling

On `didDisconnectPeripheral`:

- Invalidate heartbeat.
- Clear active peripheral and characteristics.
- Set state to disconnected.
- Keep last reading visible, but mark status disconnected.
- Optionally offer auto-reconnect later, but not required for MVP.

## SwiftUI view

Create `ContentView.swift`.

UI requirements:

- Big weight text.
- Status.
- Buttons.
- Device list when scanning finds devices.
- Debug log.

Sketch:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var scale = AcaiaScaleManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            weightDisplay
            controls
            discoveredDevices
            debugLog
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Acaia Umbra Scale")
                .font(.largeTitle.bold())

            Text(scale.state.displayText)
                .foregroundStyle(.secondary)
        }
    }

    private var weightDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(String(format: "%.1f", scale.reading.grams))
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("g")
                .font(.title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }

    private var controls: some View {
        HStack {
            Button("Scan") { scale.startScanning() }
            Button("Stop") { scale.stopScanning() }
            Button("Disconnect") { scale.disconnect() }
                .disabled(!scale.isConnected)
            Button("Tare") { scale.tare() }
                .disabled(!scale.isConnected)
            Button("Clear Log") { scale.logger.clear() }
        }
    }

    private var discoveredDevices: some View {
        GroupBox("Discovered Devices") {
            if scale.discoveredScales.isEmpty {
                Text("No Acaia-like devices found yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List(scale.discoveredScales) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text("RSSI \(device.rssi)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Connect") {
                            scale.connect(to: device)
                        }
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private var debugLog: some View {
        GroupBox("Debug Log") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(scale.logger.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 220)
        }
    }
}
```

## App entry point

Create `UmbraScaleApp.swift`:

```swift
import SwiftUI

@main
struct UmbraScaleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Testing plan

### Unit tests

Create parser tests with synthetic packets that match the provisional parser.

Example:

```swift
import XCTest
@testable import UmbraScaleApp

final class AcaiaProtocolTests: XCTestCase {
    func testNewStylePositiveWeightPacket() {
        // This synthetic packet follows the provisional parser layout.
        // It is not a real captured Umbra packet.
        let data = Data([
            0xEF, 0xDD, 0x0C, 0x00,
            0x05,
            0xE8, 0x03, // 1000 little-ish per parser layout => 100.0 with divisor 10
            0x00, 0x00,
            0x01,       // divisor exponent
            0x00,
            0x00, 0x00
        ])

        let reading = AcaiaProtocol.parseWeightPacket(data)
        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.grams ?? -1, 100.0, accuracy: 0.001)
    }

    func testNewStyleNegativeWeightPacket() {
        let data = Data([
            0xEF, 0xDD, 0x0C, 0x00,
            0x05,
            0xE8, 0x03,
            0x00, 0x00,
            0x01,
            0x02,       // sign bit
            0x00, 0x00
        ])

        let reading = AcaiaProtocol.parseWeightPacket(data)
        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.grams ?? 1, -100.0, accuracy: 0.001)
    }

    func testUnknownPacketReturnsNil() {
        let data = Data([0x01, 0x02, 0x03])
        XCTAssertNil(AcaiaProtocol.parseWeightPacket(data))
    }
}
```

Add real captured packets as soon as the app can log Umbra notifications.

### Manual test with real scale

1. Turn on the Umbra.
2. Ensure the scale Bluetooth setting is on.
3. Make sure the scale is not already connected to the Acaia mobile app or another display.
4. Launch app.
5. Click **Scan**.
6. Confirm the app logs discovered peripherals.
7. Connect to the Umbra-like device.
8. Confirm services and characteristics are logged.
9. Confirm the app finds either:
   - new write + new notify UUIDs, or
   - old `2A80` characteristic.
10. Confirm notify subscription succeeds.
11. Confirm identify, notification request, and heartbeat TX lines appear.
12. Place known weights on the scale and check whether RX packets parse into expected grams.
13. Press **Tare** and check whether reading returns to zero.

## Debugging decision tree

### Scale does not appear while scanning

- Confirm Bluetooth is on in macOS.
- Confirm the app has Bluetooth permission.
- Confirm Acaia Bluetooth setting is enabled.
- Quit Acaia mobile app or any app/device that might already be connected.
- Temporarily relax the name filter and show all peripherals with RSSI > -80.
- Log advertisement local name and service UUIDs.

### Scale appears but connection fails

- Log `didFailToConnect`.
- Ensure the `CBPeripheral` is retained in `peripheralsByID` and `activePeripheral`.
- Try disconnecting scale from other devices.
- Restart scale and retry.

### Connection works but no characteristics match

- Keep logging all services and characteristics.
- Add UI button to export log.
- Compare captured UUIDs against known transparent UART UUIDs.
- If Umbra uses different characteristics, update `AcaiaBLEUUIDs`.

### Characteristics match but no packets arrive

- Confirm notify subscription callback reports `isNotifying == true`.
- Ensure handshake is sent after subscription, not before.
- Try heartbeat interval between 2.5 and 3.0 seconds.
- Verify write type: try `.withResponse` if `.withoutResponse` does not work.
- Confirm scale is awake and not paired to another device.

### Packets arrive but weight does not parse

- Preserve all RX packet logs.
- Put 0 g, 10 g, 100 g, and negative/tared values on the scale.
- Compare byte changes between captures.
- Add an Umbra-specific parser branch.
- Do not hack the UI to show guesses; parser must be backed by packet captures.

## Implementation phases

### Phase 1: Buildable shell

- Create SwiftUI macOS app.
- Add entitlements and Bluetooth usage string.
- Add state model, logger, and basic UI.
- App builds with no BLE behavior yet.

Acceptance criteria:

- App launches.
- Buttons render.
- Debug log can append and clear messages.
- No compile warnings from missing files.

### Phase 2: BLE scan and device list

- Implement `CBCentralManagerDelegate`.
- Request Bluetooth permission naturally by constructing `CBCentralManager`.
- Scan with no service filter.
- Filter likely Acaia names.
- Show discovered devices in UI.
- Log all discovered Acaia-like peripherals.

Acceptance criteria:

- Clicking Scan changes status to Scanning.
- Nearby likely Acaia devices appear in list.
- Debug log includes name, identifier, RSSI, advertisement local name.

### Phase 3: Connect and discover

- Implement connect/disconnect.
- Discover all services and characteristics.
- Log every service and characteristic.
- Detect known Acaia characteristics.

Acceptance criteria:

- Clicking Connect transitions through connecting/discovering states.
- Logs include all service UUIDs.
- Logs identify selected write and notify characteristics.

### Phase 4: Subscribe and handshake

- Subscribe to notify characteristic.
- Only send handshake after `isNotifying == true`.
- Send identify and notification request.
- Start heartbeat timer.
- Log every TX command.

Acceptance criteria:

- Logs show notify enabled.
- Logs show identify, notification request, and heartbeat TX lines.
- No duplicate heartbeat timers after reconnecting.

### Phase 5: Weight parser

- Add provisional Acaia parser.
- Update UI on parsed packets.
- Keep logging unparsed packets.
- Add synthetic parser unit tests.

Acceptance criteria:

- Synthetic tests pass.
- Real RX packets either parse correctly or are fully logged for follow-up.
- UI weight updates when parser returns a reading.

### Phase 6: Tare

- Send tare command through write characteristic.
- Log command.
- Keep button disabled unless connected.

Acceptance criteria:

- Pressing Tare logs TX tare packet.
- On real scale, weight returns near 0.0 g if command is supported.

### Phase 7: Hardening

- Clean reconnection behavior.
- Add timeout if no packet arrives after handshake.
- Add export/copy logs button.
- Add last packet timestamp.
- Add "show all BLE devices" debug toggle.
- Prevent multiple simultaneous connections.

Acceptance criteria:

- Disconnect/reconnect does not crash.
- App explains common failures in status text.
- User can copy logs for protocol debugging.

## Code quality requirements

- Keep all CoreBluetooth delegate callbacks in `AcaiaScaleManager`.
- Keep packet parsing separate in `AcaiaProtocol`.
- Avoid doing BLE parsing directly in SwiftUI views.
- Do not block the main thread.
- Avoid force unwraps.
- Log enough detail to diagnose real hardware issues.
- Do not silently ignore BLE errors.
- Keep community-derived protocol pieces clearly labeled as provisional.
- Write tests for each parser branch once real packets are captured.

## Definition of done for MVP

The MVP is done when:

- The app builds and launches on macOS.
- It requests/uses Bluetooth permission correctly.
- It scans for and lists the Umbra or likely Acaia devices.
- It connects to the scale.
- It logs services and characteristics.
- It subscribes to notifications.
- It sends handshake and heartbeat.
- It displays live grams from parsed packets, or clearly logs raw packets if Umbra requires parser adjustment.
- The Tare button sends the command without crashing.
- Debug logs are useful enough to continue protocol work if Umbra differs from Lunar/Pearl behavior.

## Suggested first Codex task

Start by implementing the full project skeleton, UI, logger, BLE scan/connect/discover flow, and protocol constants. Do not over-optimize the parser until real Umbra packets are captured.

Prompt for Codex:

```text
Implement a native SwiftUI macOS app using CoreBluetooth based on this plan. Create the listed files, entitlements guidance, state model, BLE logger, scan/connect/discover/subscribe/handshake flow, provisional Acaia packet parser, and simple UI. Keep the code buildable and add parser unit tests with synthetic packets. Treat the Umbra BLE protocol as unverified and prioritize raw BLE logging.
```
