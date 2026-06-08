import CoreGraphics

enum ScaleHUDMode: Equatable {
    case compact
    case expanded

    var contentSize: CGSize {
        switch self {
        case .compact:
            CGSize(width: 280, height: 180)
        case .expanded:
            CGSize(width: 760, height: 620)
        }
    }
}

enum ScaleHUDPresentationAction: Equatable {
    case none
    case showCenteredAndActivate(mode: ScaleHUDMode)
    case resizeHUD(mode: ScaleHUDMode)
    case dismissHUD
}

struct ScaleHUDPresentationState: Equatable {
    var wasConnected = false
    var isHUDVisible = false
    var mode: ScaleHUDMode = .compact

    mutating func handleConnectionChange(isConnected: Bool) -> ScaleHUDPresentationAction {
        defer { wasConnected = isConnected }

        if !wasConnected && isConnected {
            isHUDVisible = true
            mode = .compact
            return .showCenteredAndActivate(mode: .compact)
        }

        if wasConnected && !isConnected {
            isHUDVisible = false
            return .dismissHUD
        }

        return .none
    }

    mutating func openExpandedFromPopup() -> ScaleHUDPresentationAction {
        isHUDVisible = true
        mode = .expanded
        return .showCenteredAndActivate(mode: .expanded)
    }

    mutating func toggleExpandedMode() -> ScaleHUDPresentationAction {
        mode = mode == .compact ? .expanded : .compact
        return .resizeHUD(mode: mode)
    }
}
