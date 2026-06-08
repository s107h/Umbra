import Testing
@testable import UmbraScaleSupport

struct ScaleHUDPresentationTests {
    @Test func connectTransitionShowsCompactHUD() {
        var state = ScaleHUDPresentationState()

        let action = state.handleConnectionChange(isConnected: true)

        #expect(action == .showCenteredAndActivate(mode: .compact))
        #expect(state.isHUDVisible)
        #expect(state.mode == .compact)
    }

    @Test func disconnectDismissesVisibleHUD() {
        var state = ScaleHUDPresentationState(wasConnected: true, isHUDVisible: true, mode: .expanded)

        let action = state.handleConnectionChange(isConnected: false)

        #expect(action == .dismissHUD)
        #expect(!state.isHUDVisible)
    }

    @Test func repeatedConnectedStateDoesNothingAfterInitialShow() {
        var state = ScaleHUDPresentationState(wasConnected: true, isHUDVisible: true, mode: .compact)

        let action = state.handleConnectionChange(isConnected: true)

        #expect(action == .none)
        #expect(state.isHUDVisible)
        #expect(state.mode == .compact)
    }

    @Test func repeatedDisconnectedStateDoesNothing() {
        var state = ScaleHUDPresentationState()

        let action = state.handleConnectionChange(isConnected: false)

        #expect(action == .none)
        #expect(!state.isHUDVisible)
    }

    @Test func popupGearOpensExpandedHUDWhileDisconnected() {
        var state = ScaleHUDPresentationState()

        let action = state.openExpandedFromPopup()

        #expect(action == .showCenteredAndActivate(mode: .expanded))
        #expect(state.isHUDVisible)
        #expect(state.mode == .expanded)
    }

    @Test func staleDisconnectedUpdateDoesNotDismissPopupOpenedHUD() {
        var state = ScaleHUDPresentationState()
        _ = state.openExpandedFromPopup()

        let action = state.handleConnectionChange(isConnected: false)

        #expect(action == .none)
        #expect(state.isHUDVisible)
        #expect(state.mode == .expanded)
    }

    @Test func gearTogglesBetweenCompactAndExpandedModes() {
        var state = ScaleHUDPresentationState(isHUDVisible: true, mode: .compact)

        #expect(state.toggleExpandedMode() == .resizeHUD(mode: .expanded))
        #expect(state.toggleExpandedMode() == .resizeHUD(mode: .compact))
    }

    @Test func hiddenHUDToggleDoesNothing() {
        var state = ScaleHUDPresentationState(isHUDVisible: false, mode: .compact)

        let action = state.toggleExpandedMode()

        #expect(action == .none)
        #expect(state.mode == .compact)
    }
}
