import 'garden_exporter.dart';

/// Result of handing an image to the platform. No `cancelled`: neither
/// platform reliably reports a dismissal, and we don't care anyway.
enum ShareOutcome {
  /// Sheet is open with the image.
  shared,

  /// Couldn't open (nothing registered, e.g. tests or desktop, or the
  /// platform refused).
  unavailable,
}

/// Hands a finished export to the platform share sheet.
///
/// There's no separate "save to photos": the share sheet already offers it on
/// both platforms. iOS shows its own permission prompt but needs
/// `NSPhotoLibraryAddUsageDescription` in `ios/Runner/Info.plist` or the app
/// crashes on Save Image. Android needs no permission (content URI via
/// `FileProvider`).
///
/// Returns [ShareOutcome.unavailable] instead of throwing.
abstract interface class GardenShare {
  /// Returns once the sheet is open, not when the user is done with it.
  Future<ShareOutcome> share(GardenExport export);
}
