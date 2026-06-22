import Foundation

struct FellowKettleBLEEndpointCandidate: Equatable, Sendable {
    let source: String
    let value: String
}

struct FellowKettleBLECandidate: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let rssi: Int
    let serviceUUIDs: [String]

    init(id: UUID, name: String, rssi: Int, serviceUUIDs: [String] = []) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.serviceUUIDs = serviceUUIDs
    }
}

struct FellowKettleBLEAdvertisementEvent: Equatable, Sendable {
    let candidateID: UUID
    let name: String
    let rssi: Int
    let serviceUUIDs: [String]
}

struct FellowKettleBLEServiceSummary: Equatable, Sendable {
    let uuid: String
}

struct FellowKettleBLECharacteristicSummary: Equatable, Sendable {
    let serviceUUID: String
    let uuid: String
    let properties: [String]
}

struct FellowKettleBLECharacteristicDiscovery: Equatable, Sendable {
    let serviceUUID: String
    let uuid: String
    let properties: [String]
}

enum FellowKettleBLEPayloadKind: Equatable, Sendable {
    case read
    case notify
}

struct FellowKettleBLEPayloadEvent: Equatable, Sendable {
    let characteristicUUID: String
    let kind: FellowKettleBLEPayloadKind
    let data: Data
    let renderedLine: String
}

struct FellowKettleBLEResearchSession: Equatable, Sendable {
    var advertisementEvents: [FellowKettleBLEAdvertisementEvent]
    var serviceSummaries: [FellowKettleBLEServiceSummary]
    var characteristicSummaries: [FellowKettleBLECharacteristicSummary]
    var readEvents: [FellowKettleBLEPayloadEvent]
    var notificationEvents: [FellowKettleBLEPayloadEvent]
    var endpointCandidates: [FellowKettleBLEEndpointCandidate]

    static let empty = FellowKettleBLEResearchSession(
        advertisementEvents: [],
        serviceSummaries: [],
        characteristicSummaries: [],
        readEvents: [],
        notificationEvents: [],
        endpointCandidates: []
    )
}
