import Flutter
import UIKit

/// iOS's half of REQ-035's share sheet.
///
/// Answers the same channel `GardenSharePlugin.kt` answers, with the same one
/// method and the same two arguments, so nothing in Dart knows which phone it
/// is on.
///
/// **`UIActivityViewController` is where Save Image lives**, which is the whole
/// of how this ticket's "reaches the share sheet" and "saves correctly to the
/// photo library" are one gesture rather than two. The user taps export, the
/// sheet comes up, and *Save Image* is one of the rows in it beside Messages
/// and Instagram.
///
/// **The photo permission is the system's to ask for, and ours to explain.**
/// Saving from the share sheet writes through the system's own code path, so
/// this app calls nothing in Photos, links no `Photos.framework` and holds no
/// authorization. What it must supply is the `NSPhotoLibraryAddUsageDescription`
/// string in `Info.plist`, which is what the system shows in the prompt — and
/// without which UIKit terminates the app at the moment the user taps Save
/// Image. That string is therefore not boilerplate: it is the only thing
/// standing between this feature and a crash, and it is why there is a comment
/// beside it in the plist.
///
/// The image is passed as a temporary file URL rather than as a `UIImage`, so
/// that the PNG this app rendered is the PNG that gets saved: handing UIKit a
/// decoded image would let each activity re-encode it, and a garden that went
/// out as a recompressed JPEG would lose exactly the flat colour it is made of.
final class GardenSharePlugin: NSObject, FlutterPlugin {

    static let channelName = "pip_garden/garden_share"

    /// The directory exports are written into: the app's own temporary space,
    /// which iOS empties on its own terms.
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
            // Reported so Dart can say the sheet did not open, rather than
            // leaving the user looking at a spinner that stopped.
            result(FlutterError(
                code: "share-failed",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }

    /// Writes the PNG somewhere the share sheet can read it from.
    private func write(_ image: Data, named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        // One file, overwritten, for the reason the Android side gives: an
        // export the user has finished with is of no further interest, and a
        // directory accumulating one PNG per tap is this app filling somebody's
        // storage with pictures they already sent.
        //
        // The last component only, for the reason the Android side gives too: a
        // name is a string crossing a channel into a path, and `../` in one
        // would write outside the directory this plugin owns.
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

        // iPad presents this as a popover and requires an anchor; without one
        // it raises rather than falling back. Anchored to the middle of the
        // presenting view, because the control that started the export is a
        // button in an app bar the plugin cannot see from here — and a popover
        // pointing at the wrong thing is worse than one pointing at nothing.
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

    /// Whatever is actually in front, which is where a sheet has to come from.
    ///
    /// Walked rather than assumed to be the root: the app is one Flutter view
    /// controller today, and a modal presented over it — a future ticket's, or
    /// the system's — would make `rootViewController` the wrong answer and the
    /// presentation silently fail.
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
