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
        var state = ScaleHUDPresentationState(isHUDVisible: true, mode: .expanded)

        let action = state.handleConnectionChange(isConnected: false)

        #expect(action == .dismissHUD)
        #expect(!state.isHUDVisible)
    }

    @Test func popupGearOpensExpandedHUDWhileDisconnected() {
        var state = ScaleHUDPresentationState()

        let action = state.openExpandedFromPopup()

        #expect(action == .showCenteredAndActivate(mode: .expanded))
        #expect(state.isHUDVisible)
        #expect(state.mode == .expanded)
    }

    @Test func gearTogglesBetweenCompactAndExpandedModes() {
        var state = ScaleHUDPresentationState(isHUDVisible: true, mode: .compact)

        #expect(state.toggleExpandedMode() == .resizeHUD(mode: .expanded))
        #expect(state.toggleExpandedMode() == .resizeHUD(mode: .compact))
    }
}
