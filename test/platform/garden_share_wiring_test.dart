import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/export/channel_garden_share.dart';

/// Native share-sheet wiring, checked from the Dart side. Nothing native builds
/// here, so these catch the silent failures:
///
/// - a channel name off by a character (export reports nowhere to send it)
/// - a `FileProvider` authority or path that doesn't match the manifest (throws
///   on every export)
/// - the Swift file missing from the Xcode target (sheet never opens)
/// - `NSPhotoLibraryAddUsageDescription` missing from `Info.plist`, which gets
///   the app killed the first time someone taps Save Image
void main() {
  late String androidPlugin;
  late String manifest;
  late String providerPaths;
  late String iosPlugin;
  late String plist;

  setUpAll(() {
    androidPlugin = File('android/app/src/main/kotlin/com/pipgarden/'
            'pip_garden/GardenSharePlugin.kt')
        .readAsStringSync();
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    providerPaths =
        File('android/app/src/main/res/xml/garden_share_paths.xml')
            .readAsStringSync();
    iosPlugin = File('ios/Runner/GardenSharePlugin.swift').readAsStringSync();
    plist = File('ios/Runner/Info.plist').readAsStringSync();
  });

  group('the one channel both platforms answer on', () {
    test('is named the same in Dart, Kotlin and Swift', () {
      const name = ChannelGardenShare.channelName;

      expect(name, 'pip_garden/garden_share');
      expect(androidPlugin, contains('"$name"'));
      expect(iosPlugin, contains('"$name"'));
    });

    test('carries the same method and the same two arguments', () {
      // Untyped map: a renamed key arrives as null and the export fails.
      for (final token in [
        ChannelGardenShare.shareMethod,
        ChannelGardenShare.imageArgument,
        ChannelGardenShare.filenameArgument,
      ]) {
        expect(androidPlugin, contains('"$token"'),
            reason: 'Android does not know about $token');
        expect(iosPlugin, contains('"$token"'),
            reason: 'iOS does not know about $token');
      }
    });

    test('is reached through exactly one implementation', () {
      // A second implementation picked in Dart would pass every platform-branch
      // check and still break the one-port rule.
      final implementations = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) =>
              file.readAsStringSync().contains('implements GardenShare'))
          .map((file) => file.path)
          .toList();

      expect(implementations, ['lib/src/export/channel_garden_share.dart']);
    });

    test('and neither side branches on which platform it is', () {
      // Platform differences stay native. Checked against code only, since the
      // comments discuss both platforms.
      expect(
        _code(File('lib/src/export/channel_garden_share.dart')
            .readAsStringSync()),
        isNot(contains('Platform.is')),
      );
    });
  });

  group('Android', () {
    test('vends the image through a FileProvider, not a file path', () {
      // `file://` across apps has thrown FileUriExposedException since Nougat.
      expect(androidPlugin, contains('FileProvider.getUriForFile'));
      expect(manifest, contains('androidx.core.content.FileProvider'));
    });

    test('the authority in the manifest is the one the plugin asks for', () {
      // Has to match exactly or every export throws.
      expect(androidPlugin, contains(r'"${context.packageName}.gardenshare"'));
      expect(
        manifest,
        contains(r'android:authorities="${applicationId}.gardenshare"'),
      );
    });

    test('the provider exposes the directory the plugin writes to', () {
      // Only that directory; the whole cache would expose database temp files.
      expect(androidPlugin, contains('const val SHARE_DIRECTORY = '
          '"garden-exports"'));
      // Checked against the element's attributes, not the file text, since a
      // comment quotes the wide config.
      final declared = providerPaths.replaceAll(
        RegExp(r'<!--.*?-->', dotAll: true),
        '',
      );
      final exposed = RegExp(r'<cache-path\s[^>]*?path="([^"]*)"', dotAll: true)
          .allMatches(declared)
          .map((match) => match.group(1))
          .toList();

      expect(exposed, ['garden-exports/'],
          reason: 'anything wider exposes the rest of the cache directory');
      expect(
        RegExp(r'<(files|external|external-files|external-cache|root)-path')
            .hasMatch(declared),
        isFalse,
        reason: 'the export lives in the cache and nowhere else',
      );
      expect(manifest, contains('@xml/garden_share_paths'));
    });

    test('grants the read the receiving app needs', () {
      // Without the flag the receiving app can't load the image.
      expect(androidPlugin, contains('FLAG_GRANT_READ_URI_PERMISSION'));
      expect(manifest, contains('android:grantUriPermissions="true"'));
    });

    test('opens the chooser rather than a single app', () {
      expect(androidPlugin, contains('Intent.ACTION_SEND'));
      expect(androidPlugin, contains('Intent.createChooser'));
      expect(androidPlugin, contains('"image/png"'));
      // Started from the application context, so it needs its own task.
      expect(androidPlugin, contains('FLAG_ACTIVITY_NEW_TASK'));
    });

    test('asks for no storage permission, because it needs none', () {
      // The receiving app saves under its own permissions.
      expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
      expect(manifest, isNot(contains('READ_MEDIA_IMAGES')));
    });

    test('writes the basename, not whatever name it was sent', () {
      // The name crosses a channel into a path join. Dart sends a constant
      // today, but this keeps writes inside the provider's directory
      // regardless.
      expect(androidPlugin, contains('File(directory, File(filename).name)'));
    });

    test('registers the plugin with the engine', () {
      // An unregistered plugin looks like a device with nowhere to send an
      // image.
      expect(
        File('android/app/src/main/kotlin/com/pipgarden/pip_garden/'
                'MainActivity.kt')
            .readAsStringSync(),
        contains('GardenSharePlugin('),
      );
    });
  });

  group('iOS', () {
    test('opens the system share sheet', () {
      expect(iosPlugin, contains('UIActivityViewController'));
    });

    test('declares why it may add to the photo library', () {
      // Saving from the sheet writes on the app's behalf, and UIKit kills the
      // process if the reason is missing. Empty fails App Review (and can still
      // crash).
      expect(plist, contains('<key>NSPhotoLibraryAddUsageDescription</key>'));

      final reason = RegExp(
        r'<key>NSPhotoLibraryAddUsageDescription</key>\s*<string>(.*?)</string>',
        dotAll: true,
      ).firstMatch(plist)?.group(1);

      expect(reason, isNotNull);
      expect(reason!.trim(), isNotEmpty);
    });

    test('and asks for no more than adding', () {
      // Read access is a different, much wider prompt; not needed.
      expect(plist, isNot(contains('<key>NSPhotoLibraryUsageDescription</key>')));
    });

    test('hands over the PNG itself rather than a decoded image', () {
      // A `UIImage` would let activities re-encode it as JPEG and muddy the
      // flat colour.
      expect(iosPlugin, contains('activityItems: [file]'));
    });

    test('writes the basename, not whatever name it was sent', () {
      expect(iosPlugin, contains('(filename as NSString).lastPathComponent'));
    });

    test('anchors the popover, which iPad requires', () {
      // Without a source rect, iPad throws instead of falling back.
      expect(iosPlugin, contains('popoverPresentationController'));
      expect(iosPlugin, contains('sourceRect'));
    });

    test('is built into the app target', () {
      // Left out of the target, the plugin never registers.
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      expect(
        RegExp(r'isa = PBXBuildFile; fileRef = \w+ '
                r'/\* GardenSharePlugin\.swift ')
            .allMatches(project),
        hasLength(1),
        reason: 'GardenSharePlugin.swift is not built into the Runner target.',
      );
    });

    test('registers the plugin with the engine', () {
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('GardenSharePlugin.register(with: registrar)'),
      );
    });
  });
}

/// [source] with comment lines removed. Same helper as
/// `quiet_mode_wiring_test.dart`.
String _code(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('/*');
    })
    .join('\n');
