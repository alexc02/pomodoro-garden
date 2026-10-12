import Flutter
import UIKit

/// Share sheet on iOS; same channel and arguments as `GardenSharePlugin.kt`.
///
/// Save Image in `UIActivityViewController` handles the photo library, so no
/// Photos code here. `NSPhotoLibraryAddUsageDescription` in `Info.plist` is
/// still required or UIKit kills the app when the user taps Save Image.
///
/// Shared as a file URL, not a `UIImage`, so the PNG isn't re-encoded.
final class GardenSharePlugin: NSObject, FlutterPlugin {

    static let channelName = "pip_garden/garden_share"

    /// Under the temp directory.
    private static let directoryName = "garden-exports"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(GardenSharePlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "share" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard
            let arguments = call.arguments as? [String: Any],
            let image = arguments["image"] as? FlutterStandardTypedData
        else {
            result(FlutterError(
                code: "no-image",
                message: "share was called with no image",
                details: nil
            ))
            return
        }
        let filename = arguments["filename"] as? String ?? "garden.png"

        do {
            let file = try write(image.data, named: filename)
            try present(file)
            result(nil)
        } catch {
            result(FlutterError(
                code: "share-failed",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    private func write(_ image: Data, named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        // One file, overwritten each export. Last path component only, so a
        // `../` in the name can't escape the directory.
        let file = directory.appendingPathComponent(
            (filename as NSString).lastPathComponent
        )
        try image.write(to: file, options: .atomic)
        return file
    }

    private func present(_ file: URL) throws {
        guard let presenter = Self.topViewController() else {
            throw NSError(
                domain: "pip_garden.garden_share",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "There was no view controller to present the share sheet from."
                ]
            )
        }

        let sheet = UIActivityViewController(
            activityItems: [file],
            applicationActivities: nil
        )

        // iPad crashes without a popover anchor. The export button isn't
        // visible from here, so anchor to the middle with no arrow.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(sheet, animated: true)
    }

    /// Walks presented controllers; presenting from the root fails silently
    /// if a modal is up.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first

        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
