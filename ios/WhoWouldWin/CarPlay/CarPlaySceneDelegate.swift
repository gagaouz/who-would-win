import CarPlay
import UIKit

/// Lifecycle delegate for the CarPlay template scene.
/// Registered in Info.plist under CPTemplateApplicationSceneSessionRoleApplication.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var coordinator: CarPlayCoordinator?

    // Called when a CarPlay head-unit connects.
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        let c = CarPlayCoordinator(interfaceController: interfaceController)
        self.coordinator = c
        c.start()
    }

    // Called when the head-unit disconnects or app moves to background.
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        coordinator?.tearDown()
        coordinator = nil
    }
}
