import 'garden_exporter.dart';

/// What the platform did with an image it was handed.
///
/// **Two members, and there is deliberately no `cancelled`.** Neither
/// `UIActivityViewController` nor Android's chooser reports back usefully when
/// the user dismisses it — iOS's completion handler can say an activity was not
/// performed, Android's `ACTION_SEND` says nothing at all — and the app has no
/// business acting on it either way. A user who opened the sheet and changed
/// their mind has exported their garden; they simply did not send it anywhere.
/// What the app must tell them apart from is a sheet that never opened.
enum ShareOutcome {
  /// The sheet is up, and the image is in it.
  shared,

  /// It could not be opened: no implementation registered — a widget test, a
  /// desktop host — or a platform that refused. The user is told, because they
  /// tapped a button and nothing happened.
  unavailable,
}

/// Handing a finished export to the platform. REQ-035.
///
/// **One method, because there is one action.** The ticket asks that the image
/// reach the native share sheet *and* save correctly to the photo library, and
/// on both platforms those are the same gesture rather than two: the share
/// sheet is where **Save Image** lives on iOS and where the Photos app appears
/// as a target on Android. A second "save to photos" button beside the share
/// one would be a worse app — two ways to do one thing, one of which the
/// platform already offers inside the other.
///
/// **So the photo permission is handled where the platform requires it, and
/// nowhere else.** On iOS the *system* presents the permission prompt when the
/// user taps Save Image, and the only thing the app must supply is the
/// `NSPhotoLibraryAddUsageDescription` string it shows — which is in
/// `ios/Runner/Info.plist`, and without which the app is terminated at that tap
/// rather than refused. On Android nothing is required: the image goes to the
/// receiving app as a content URI through a `FileProvider`, and the app that
/// saves it does so under its own permissions. There is no runtime permission
/// call in Dart because on neither platform is there one to make.
///
/// Best-effort by contract, like every other platform port in this app: it
/// reports [ShareOutcome.unavailable] rather than throwing, so a build with
/// nothing registered behind it is a button that says it could not do it.
abstract interface class GardenShare {
  /// Puts [export] in the platform's share sheet.
  ///
  /// Returns once the sheet is *open*, not once the user has finished with it.
  /// The app has no interest in what they choose — see [ShareOutcome].
  Future<ShareOutcome> share(GardenExport export);
}
