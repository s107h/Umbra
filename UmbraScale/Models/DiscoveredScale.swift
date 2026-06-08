@preconcurrency import CoreBluetooth
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
