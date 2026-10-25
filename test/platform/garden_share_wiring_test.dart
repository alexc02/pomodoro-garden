import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/export/channel_garden_share.dart';

/// The platform half of ticket 21, asserted from the only side that can be run
/// here.
///
/// None of the Kotlin or the Swift compiles on this machine and there is no
/// device to run it on, so what these tests catch are the *silent* failures —
/// and REQ-035 has an unusually nasty set of them:
///
/// - A channel name that differs by a character is an export that renders
///   perfectly and then reports that the device had nowhere to send it.
/// - A `FileProvider` authority that does not match the manifest is a
///   `IllegalArgumentException` at the moment the user taps export, every time.
/// - A provider path that does not match the directory the plugin writes to is
///   the same failure with a different message.
/// - A Swift file missing from the Xcode target is a share sheet that never
///   opens on iOS and compiles fine.
/// - And `NSPhotoLibraryAddUsageDescription` missing from `Info.plist` is not
///   a refusal: it is the *app being terminated* the first time anybody taps
///   Save Image in the sheet. Nothing warns at build time, and no simulator run
///   that stops short of that tap shows it.
///
/// Every one of those is a string in two files that have to agree, which is
/// exactly the thing a test can hold together and a reviewer cannot.
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
      // The arguments are read out of an untyped map on both sides, so a
      // renamed key arrives as null — which is an export that fails with
      // "share was called with no image" and a picture that was drawn for
      // nothing.
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
      // The other half of "one shared port": an override point that exists, and
      // one of it. A second implementation chosen in Dart would satisfy every
      // platform-branch check and break the same rule.
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
      // The rule `ChannelQuietMode` states and this file inherits: the two
      // platforms differ in how they open a sheet, and that difference stays
      // native. A `Platform.isAndroid` in Dart would put half of each
      // platform's design on the wrong side of the port.
      // Read from the code rather than the file: the comments in these files
      // discuss the two platforms at length, and most of what they say is why
      // there is no branch here.
      expect(
        _code(File('lib/src/export/channel_garden_share.dart')
            .readAsStringSync()),
        isNot(contains('Platform.is')),
      );
    });
  });

  group('Android', () {
    test('vends the image through a FileProvider, not a file path', () {
      // `file://` across an app boundary has thrown FileUriExposedException
      // since Nougat. The chooser would open and every target would fail.
      expect(androidPlugin, contains('FileProvider.getUriForFile'));
      expect(manifest, contains('androidx.core.content.FileProvider'));
    });

    test('the authority in the manifest is the one the plugin asks for', () {
      // Two strings in two languages that have to agree exactly, and the
      // failure is a throw on every single export.
      expect(androidPlugin, contains(r'"${context.packageName}.gardenshare"'));
      expect(
        manifest,
        contains(r'android:authorities="${applicationId}.gardenshare"'),
      );
    });

    test('the provider exposes the directory the plugin writes to', () {
      // And only that directory. A provider configured for the whole cache
      // would expose the database's temporary files to any app that could
      // guess a name.
      expect(androidPlugin, contains('const val SHARE_DIRECTORY = '
          '"garden-exports"'));
      // Asserted against the element's own attributes rather than against the
      // file's text, so that the comment above it — which quotes the wide
      // configuration this is deliberately not — cannot satisfy or break it.
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
      // Without the flag the chooser opens and nothing in it can load the
      // image — a share sheet that appears to work and produces a broken
      // picture in whatever the user picked.
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
      // The receiving app saves under its own permissions. An app that wrote to
      // the media store itself would be holding a permission to do a thing the
      // chooser already does.
      expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
      expect(manifest, isNot(contains('READ_MEDIA_IMAGES')));
    });

    test('writes the basename, not whatever name it was sent', () {
      // A name is a string crossing a channel into a path join. Dart sends a
      // constant today, and this is what keeps that from being the only thing
      // standing between a renamed export and a write outside the one directory
      // the provider is configured for.
      expect(androidPlugin, contains('File(directory, File(filename).name)'));
    });

    test('registers the plugin with the engine', () {
      // A plugin nothing constructs answers nothing, and the failure looks
      // exactly like a device with nowhere to send an image.
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
      // **The one that crashes.** Saving from the sheet writes on the app's
      // behalf, so the app is the one that must have declared a reason — and
      // UIKit terminates a process that reaches the prompt without one. The
      // string is asserted to be non-empty because an empty one fails App
      // Review and, on some versions, terminates just the same.
      expect(plist, contains('<key>NSPhotoLibraryAddUsageDescription</key>'));

      final reason = RegExp(
        r'<key>NSPhotoLibraryAddUsageDescription</key>\s*<string>(.*?)</string>',
        dotAll: true,
      ).firstMatch(plist)?.group(1);

      expect(reason, isNotNull);
      expect(reason!.trim(), isNotEmpty);
    });

    test('and asks for no more than adding', () {
      // The *read* permission is a different prompt with a much wider scope,
      // and this app has no business with anybody's existing photos.
      expect(plist, isNot(contains('<key>NSPhotoLibraryUsageDescription</key>')));
    });

    test('hands over the PNG itself rather than a decoded image', () {
      // A `UIImage` would let each activity re-encode, and a garden that went
      // out as a recompressed JPEG would lose exactly the flat colour it is
      // made of.
      expect(iosPlugin, contains('activityItems: [file]'));
    });

    test('writes the basename, not whatever name it was sent', () {
      expect(iosPlugin, contains('(filename as NSString).lastPathComponent'));
    });

    test('anchors the popover, which iPad requires', () {
      // Without a source rect, presenting on iPad raises rather than falling
      // back — an export that crashes on one form factor and not the other.
      expect(iosPlugin, contains('popoverPresentationController'));
      expect(iosPlugin, contains('sourceRect'));
    });

    test('is built into the app target', () {
      // A Swift file existing on disk is not the same as its being compiled.
      // Left out of the target, the plugin never registers and every export
      // reports that the device had nowhere to send it.
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

/// [source] with its comment lines taken out.
///
/// The same helper `quiet_mode_wiring_test.dart` needs and for the same reason:
/// an assertion that some API is *not* used has to be made against the code,
/// because the comments in these files spend most of their time explaining why
/// it is not.
String _code(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('/*');
    })
    .join('\n');
