import Foundation
import Sparkle

@MainActor
final class SoftwareUpdateController {
    static let shared = SoftwareUpdateController()

    let updaterController: SPUStandardUpdaterController

    var updater: SPUUpdater {
        updaterController.updater
    }

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
}
